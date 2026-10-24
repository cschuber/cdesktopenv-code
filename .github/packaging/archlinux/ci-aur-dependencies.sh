#!/usr/bin/env bash
# Build the declared mksh dependency when it is unavailable in Arch repositories.
set -Eeuo pipefail
work="${RUNNER_TEMP:?}/cde-arch-ci"
metadata="$work/original.SRCINFO"
if ! grep -Eq '^[[:space:]]*depends = mksh([<=>].*)?$' "$metadata"; then exit 0; fi
if pacman -T mksh >/dev/null; then exit 0; fi
if pacman -Si mksh >/dev/null 2>&1; then exit 0; fi
dep="$work/aur-mksh"
out="$work/out/dependencies/mksh"
evidence="$work/dependency-evidence/mksh"
install -d "$evidence"
git clone https://aur.archlinux.org/mksh.git "$dep"
git -C "$dep" fsck --full
git -C "$dep" rev-parse HEAD > "$evidence/aur-revision"
git -C "$dep" rev-parse 'HEAD^{tree}' > "$evidence/aur-tree"
git -C "$dep" cat-file commit HEAD > "$evidence/aur-commit"
git -C "$dep" archive HEAD > "$evidence/aur-tree.tar"
(cd "$dep"; git ls-files -z | xargs -0 sha256sum) > "$evidence/aur-files.sha256"
printf 'Official AUR mksh revision: '; cat "$evidence/aur-revision"
cat "$dep/PKGBUILD"
id aurbuild >/dev/null 2>&1 || useradd -m -s /bin/bash aurbuild
install -d -o aurbuild -g aurbuild "$out" "$work/mksh-logs"
chown aurbuild:aurbuild "$dep"
# Keep tracked files immutable while leaving build directories writable.
git -C "$dep" -c safe.directory="$dep" ls-files -z | while IFS= read -r -d '' f; do
  chmod a-w "$dep/$f"
done
printf 'aurbuild ALL=(root) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/cde-arch-aurdeps
chmod 440 /etc/sudoers.d/cde-arch-aurdeps
visudo -cf /etc/sudoers.d/cde-arch-aurdeps
set +e
runuser -u aurbuild -- env HOME=/home/aurbuild PKGDEST="$out" LOGDEST="$work/mksh-logs" \
  bash -c 'cd "$1"; exec makepkg --syncdeps --noconfirm --log' _ "$dep" \
  2>&1 | tee "$evidence/build.log"
statuses=("${PIPESTATUS[@]}")
set -e
printf '%s\n' "${statuses[0]}" > "$evidence/makepkg-exit-status"
(cd "$dep"; sha256sum --check "$evidence/aur-files.sha256")
test "${statuses[1]}" = 0
test "${statuses[0]}" = 0
shopt -s nullglob
archives=("$out"/*.pkg.tar.zst)
(( ${#archives[@]} > 0 ))
main=''
for p in "${archives[@]}"; do
  name="$(bsdtar -xOf "$p" .PKGINFO | sed -n 's/^pkgname = //p')"
  case "$name" in
    mksh) test -z "$main"; main="$p";;
    mksh-debug) :;;
    *) echo "Unexpected dependency package: $name" >&2; exit 1;;
  esac
done
test -n "$main"
pacman -U --noconfirm -- "$main"
cp "$evidence"/{aur-revision,aur-tree,aur-commit,aur-tree.tar,aur-files.sha256} "$out/"
pacman -Q mksh
