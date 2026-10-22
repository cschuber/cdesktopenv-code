#!/usr/bin/env bash
# Build the AUR package against the selected CDE commit.
set -Eeuo pipefail
stage="${1:?stage required}"
work="${RUNNER_TEMP:?}/cde-arch-ci"
pkg="$work/pkg"
mirror="$work/source.git"
expected="${CDE_EXPECTED_SHA:?}"
repository="${CDE_SOURCE_REPOSITORY:?}"
upstream='https://git.code.sf.net/p/cdesktopenv/code'
aur='https://aur.archlinux.org/cdesktopenv-git.git'

builder_run() {
  runuser -u cdebuild -- env HOME=/home/cdebuild \
    PKGDEST="$work/out" LOGDEST="$work/logs" \
    bash -c 'cd "$1"; shift; exec "$@"' _ "$pkg" "$@"
}
builder() {
  builder_run makepkg "$@"
}
recipe_integrity() {
  (cd "$pkg"; sha256sum --check "$work/aur-supporting-files.sha256")
  # Allow makepkg's pkgver/pkgrel update.
  python "$GITHUB_WORKSPACE/.github/packaging/archlinux/ci-verify-recipe.py" \
    "$work/original-PKGBUILD" "$pkg/PKGBUILD"
}

source_integrity() {
  local source="$pkg/src/code" actual actual_tree expected_tree
  actual="$(git -c safe.directory="$source" -C "$source" rev-parse HEAD)"
  actual_tree="$(git -c safe.directory="$source" -C "$source" rev-parse 'HEAD^{tree}')"
  expected_tree="$(cat "$work/expected-tree")"
  if test "$actual" != "$expected" || test "$actual_tree" != "$expected_tree"; then
    printf 'Prepared source SHA: %s\nExpected source SHA: %s\nPrepared tree: %s\nExpected tree: %s\n' \
      "$actual" "$expected" "$actual_tree" "$expected_tree" >&2
  fi
  test "$actual" = "$expected" || { echo 'FATAL: source commit mismatch' >&2; return 1; }
  test "$actual_tree" = "$expected_tree" || { echo 'FATAL: source tree mismatch' >&2; return 1; }
  printf '%s\n' "$expected" > "$work/verified-source-sha"
  printf '%s\n' "$expected_tree" > "$work/verified-source-tree"
}
source_changes() {
  local label="$1" source="$pkg/src/code"
  # Include staged and unstaged changes at each checkpoint.
  git -c safe.directory="$source" -C "$source" diff HEAD --binary > "$work/source-$label.patch"
  git -c safe.directory="$source" -C "$source" diff HEAD --stat > "$work/source-$label-stat.txt"
  git -c safe.directory="$source" -C "$source" status --porcelain=v1 --untracked-files=all \
    > "$work/source-$label-status.txt"
}
case "$stage" in
  seed)
    git config --global --add safe.directory "$GITHUB_WORKSPACE"
    [[ "$expected" =~ ^[a-f0-9]{40}$ ]]
    test "$(git -C "$GITHUB_WORKSPACE" rev-parse HEAD)" = "$expected"
    test -z "$(git -C "$GITHUB_WORKSPACE" status --porcelain)"
    git -C "$GITHUB_WORKSPACE" rev-parse 'HEAD^{tree}' > "$work/expected-tree"
    printf '%s\n' "$expected" > "$work/expected-sha"
    printf '%s\n' "$repository" > "$work/source-repository"
    printf '%s\n' "${GITHUB_EVENT_NAME:?} ${GITHUB_REF:?}" > "$work/event-reference"
    git clone --mirror --no-local "$GITHUB_WORKSPACE" "$mirror"
    # Select the commit as the default branch without changing history.
    git --git-dir="$mirror" update-ref refs/heads/master "$expected"
    git --git-dir="$mirror" symbolic-ref HEAD refs/heads/master
    test "$(git --git-dir="$mirror" rev-parse 'HEAD^{tree}')" = "$(cat "$work/expected-tree")"
    # Drop other refs so makepkg follows the selected master.
    while IFS= read -r ref; do
      case "$ref" in
        refs/heads/master|refs/tags/*) :;;
        *) git --git-dir="$mirror" update-ref -d "$ref";;
      esac
    done < <(git --git-dir="$mirror" for-each-ref --format='%(refname)')
    git --git-dir="$mirror" config --remove-section remote.origin
    chmod -R a-w "$mirror"

    git clone "$aur" "$work/aur"
    git -C "$work/aur" fsck --full
    git -C "$work/aur" rev-parse HEAD > "$work/aur-revision"
    git -C "$work/aur" rev-parse 'HEAD^{tree}' > "$work/aur-tree"
    git -C "$work/aur" cat-file commit HEAD > "$work/aur-commit"
    git -C "$work/aur" archive HEAD > "$work/aur-tree.tar"
    tar -xf "$work/aur-tree.tar" -C "$pkg"
    cp "$pkg/PKGBUILD" "$work/original-PKGBUILD"
    (cd "$pkg"; find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$work/aur-files.sha256"
    (cd "$pkg"; sha256sum PKGBUILD) > "$work/PKGBUILD.sha256"
    (cd "$pkg"; find . -type f ! -path ./PKGBUILD -print0 |
      sort -z | xargs -0 sha256sum) > "$work/aur-supporting-files.sha256"
    printf 'Official AUR revision: '; cat "$work/aur-revision"
    cat "$work/PKGBUILD.sha256"
    cat "$pkg/PKGBUILD"
    # Keep supporting files read-only; makepkg updates PKGBUILD version fields.
    chown -R cdebuild:cdebuild "$pkg" "$work/out" "$work/logs"
    find "$pkg" -type f -exec chown root:root '{}' + -exec chmod a-w '{}' +
    chown cdebuild:cdebuild "$pkg/PKGBUILD"
    chmod u+w "$pkg/PKGBUILD"
    cmp "$pkg/PKGBUILD" "$work/original-PKGBUILD"
    # Seed makepkg's VCS cache; --holdver prevents an upstream refresh.
    git clone --mirror --no-local "$mirror" "$pkg/code"
    git --git-dir="$pkg/code" config remote.origin.url "$upstream"
    test "$(git --git-dir="$pkg/code" rev-parse HEAD)" = "$expected"
    test "$(git --git-dir="$pkg/code" rev-parse 'HEAD^{tree}')" = "$(cat "$work/expected-tree")"
    chown -R cdebuild:cdebuild "$pkg/code"
    sudo_file=/etc/sudoers.d/cde-arch-makepkg
    printf 'cdebuild ALL=(root) NOPASSWD: /usr/bin/pacman\n' > "$sudo_file"
    chmod 440 "$sudo_file"
    visudo -cf "$sudo_file"
    # Read recipe metadata as the build user.
    builder --printsrcinfo > "$work/original.SRCINFO"
    # The cache layout expects the recipe's single Git source.
    mapfile -t vcs < <(sed -n 's/^[[:space:]]*source = \(.*git+.*\)$/\1/p' "$work/original.SRCINFO")
    test "${#vcs[@]}" = 1
    test "${vcs[0]}" = "git+$upstream"
    recipe_integrity
    printf 'Verified native source cache HEAD: %s\n' "$expected"
    ;;
  aur-dependencies)
    bash "$GITHUB_WORKSPACE/.github/packaging/archlinux/ci-aur-dependencies.sh"
    ;;
  dependencies)
    recipe_integrity
    test "$(git -c safe.directory="$pkg/code" --git-dir="$pkg/code" rev-parse HEAD)" = "$expected"
    test "$(git -c safe.directory="$pkg/code" --git-dir="$pkg/code" rev-parse 'HEAD^{tree}')" = "$(cat "$work/expected-tree")"
    # Resolve dependencies and prepare the package sources.
    set +e
    builder --holdver --syncdeps --nobuild --noconfirm --log 2>&1 | tee "$RUNNER_TEMP/package-build.log"
    statuses=("${PIPESTATUS[@]}")
    set -e
    printf '%s\n' "${statuses[0]}" > "$work/makepkg-preparation-exit-status"
    recipe_integrity
    test "${statuses[1]}" = 0
    test "${statuses[0]}" = 0
    source_integrity
    source_changes after-preparation
    cp "$pkg/PKGBUILD" "$work/native-PKGBUILD"
    (cd "$work"; sha256sum native-PKGBUILD) > "$work/native-PKGBUILD.sha256"
    ;;
  provenance)
    recipe_integrity
    source_integrity
    {
      printf 'Image: archlinux:base-devel\n'
      printf 'Official AUR URL: %s\nAUR revision: ' "$aur"; cat "$work/aur-revision"
      printf 'Source repository: %s\nSource SHA: %s\nSource tree: ' "$repository" "$expected"
      cat "$work/expected-tree"
      cat "$work/event-reference" "$work/PKGBUILD.sha256" /etc/os-release
      uname -sm
      id cdebuild
      printf '\nToolchain:\n'
      gcc --version
      ld --version
      make --version
      autoconf --version
      automake --version
      libtoolize --version
      makepkg --version
      printf '\nInstalled package database:\n'
      pacman -Q | sort
      printf '\nNative makepkg configuration:\n'
      cat /etc/makepkg.conf
      if test -d /etc/makepkg.conf.d; then
        find /etc/makepkg.conf.d -type f -exec cat '{}' +
      fi
      printf '\nBuilder environment (before makepkg):\n'
      builder_run bash -c '
        id
        for key in HOME USER LOGNAME PKGDEST LOGDEST CC CXX CPPFLAGS CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS IFFEFLAGS LANG LC_ALL; do
          printf "%s=%s\n" "$key" "${!key-<unset>}"
        done
        for config in "$HOME/.makepkg.conf" "${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf"; do
          if test -f "$config"; then
            printf "\nConfiguration file: %s\n" "$config"
            cat "$config"
          fi
        done
      '
    } > "$work/provenance.txt"
    cat "$work/provenance.txt"
    python "$GITHUB_WORKSPACE/.github/packaging/archlinux/ci-motif-provenance.py" \
      --phase build --output-dir "$work" --aur-revision "$(cat "$work/aur-revision")"
    ;;
  build)
    recipe_integrity
    source_integrity
    # Reuse the verified sources without fetching or preparing them again.
    set +e
    builder --noextract --holdver --noconfirm --log 2>&1 | tee -a "$RUNNER_TEMP/package-build.log"
    statuses=("${PIPESTATUS[@]}")
    set -e
    printf '%s\n' "${statuses[0]}" > "$work/makepkg-exit-status"
    source_changes after-build
    recipe_integrity
    source_integrity
    test "${statuses[1]}" = 0
    exit "${statuses[0]}"
    ;;
  collect)
    recipe_integrity
    source_integrity
    test "$(cat "$work/makepkg-exit-status")" = 0
    shopt -s nullglob
    archives=("$work"/out/*.pkg.tar.zst)
    (( ${#archives[@]} > 0 ))
    count=0
    for archive in "${archives[@]}"; do
      pacman -Qip "$archive"
      bsdtar -xOf "$archive" .PKGINFO > "$archive.PKGINFO"
      bsdtar -xOf "$archive" .BUILDINFO > "$archive.BUILDINFO"
      bsdtar -tf "$archive" > "$archive.filelist"
      name="$(sed -n 's/^pkgname = //p' "$archive.PKGINFO")"
      case "$name" in
        cdesktopenv-git) ((count+=1));;
        cdesktopenv-git-debug) :;;
        *) echo "Unexpected AUR package: $name" >&2; exit 1;;
      esac
    done
    test "$count" = 1
    for f in expected-sha expected-tree source-repository event-reference \
      verified-source-sha verified-source-tree aur-revision aur-tree \
      aur-tree.tar aur-commit aur-files.sha256 aur-supporting-files.sha256 PKGBUILD.sha256 original-PKGBUILD native-PKGBUILD native-PKGBUILD.sha256 \
      original.SRCINFO provenance.txt; do
      cp "$work/$f" "$work/out/$f"
    done
    cp "$work"/source-after-{preparation,build}* "$work"/motif-build.{txt,json,md} "$work/out/"
    cp "$pkg/PKGBUILD" "$work/out/native-PKGBUILD"
    (cd "$work/out"; sha256sum native-PKGBUILD > native-PKGBUILD.sha256)
    builder --printsrcinfo > "$work/out/effective.SRCINFO"
    # Checksum packages and their accompanying metadata.
    (cd "$work/out"; find . -type f ! -path ./SHA256SUMS -print0 |
      sort -z | xargs -0 sha256sum > SHA256SUMS)
    ;;
  diagnostics)
    bundle="$RUNNER_TEMP/ci-diagnostics/build"
    mkdir -p "$bundle/config-logs" "$bundle/makepkg-logs"
    for f in "$RUNNER_TEMP/package-build.log" "$work"/*.{txt,patch,json,md} \
      "$work"/{expected-sha,expected-tree,event-reference,source-repository,verified-source-sha,verified-source-tree,aur-revision,aur-tree,aur-commit,aur-tree.tar,aur-files.sha256,aur-supporting-files.sha256,PKGBUILD.sha256,original-PKGBUILD,native-PKGBUILD,native-PKGBUILD.sha256,original.SRCINFO,makepkg-exit-status,makepkg-preparation-exit-status}; do
      if test -f "$f"; then cp "$f" "$bundle/${f##*/}"; fi
    done
    if test -d "$work/dependency-evidence"; then
      cp -a "$work/dependency-evidence" "$bundle/"
    fi
    {
      cat /etc/os-release
      uname -sm
      gcc --version
      ld --version
      makepkg --version
      pacman -Q | sort
      cat /etc/makepkg.conf
    } > "$bundle/native-environment.txt"
    if test -d "$work/logs"; then
      find "$work/logs" -maxdepth 1 -type f -name '*.log' -exec cp '{}' "$bundle/makepkg-logs/" ';'
    fi
    if test -d "$pkg/src/code/.git"; then
      {
        git -c safe.directory="$pkg/src/code" -C "$pkg/src/code" show --no-patch --format='%H %T %s'
        git -c safe.directory="$pkg/src/code" -C "$pkg/src/code" branch -avv
        git -c safe.directory="$pkg/src/code" -C "$pkg/src/code" status --short
      } > "$bundle/actual-source.txt"
    fi
    if test -d "$pkg/src"; then
      while IFS= read -r -d '' f; do
        rel="${f#"$pkg/src/"}"
        cp "$f" "$bundle/config-logs/${rel//\//_}"
      done < <(find "$pkg/src" -type f \( -name config.log -o -name config.status \) -print0)
    fi
    ;;
  *) echo "Unknown stage: $stage" >&2; exit 2;;
esac
