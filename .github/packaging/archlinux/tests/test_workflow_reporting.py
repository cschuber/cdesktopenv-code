"""Test workflow summaries and fallback diagnostics."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

WORKFLOW = Path(__file__).resolve().parents[3] / "workflows/package-archlinux-rolling.yml"


def step_script(name):
    text = WORKFLOW.read_text().split("      - name: " + name + "\n", 1)[1]
    text = text.split("        run: |\n", 1)[1]
    lines = []
    for line in text.splitlines():
        if line.strip() and not line.startswith("          "):
            break
        lines.append(line)
    return textwrap.dedent("\n".join(lines))


class WorkflowReportingTests(unittest.TestCase):
    def test_both_gates_report_every_mandatory_failure(self):
        for name in ("Check build results", "Check install results"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                summary = Path(directory) / "summary.md"
                env = dict(os.environ, GITHUB_STEP_SUMMARY=str(summary), CI_JOB_LABEL="test",
                           CI_STAGE_OUTCOMES="Build package=failure\nCollect packages=skipped\nNamcap (advisory)=failure")
                result = subprocess.run(["bash", "-c", step_script(name)], env=env,
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Mandatory stage Build package: failure", result.stdout)
                self.assertIn("Mandatory stage Collect packages: skipped", result.stdout)
                self.assertIn("| Namcap (advisory) | failure | no |", summary.read_text())

    def test_advisory_failure_does_not_fail_either_gate(self):
        for name in ("Check build results", "Check install results"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                env = dict(os.environ, GITHUB_STEP_SUMMARY=str(Path(directory) / "summary.md"),
                           CI_JOB_LABEL="test",
                           CI_STAGE_OUTCOMES="Installation=success\nNamcap (advisory)=failure")
                result = subprocess.run(["bash", "-c", step_script(name)], env=env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_fallbacks_preserve_evidence_without_checkout(self):
        for name in ("Collect build diagnostics",
                     "Collect install diagnostics"):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "arch-bootstrap.log").write_text("bootstrap failed\n")
                env = dict(os.environ, RUNNER_TEMP=str(root), CI_CHECKOUT_OUTCOME="skipped",
                           CI_STAGE_OUTCOMES="Bootstrap=failure\nCheckout=skipped",
                           CDE_SOURCE_REPOSITORY="owner/repo", CDE_EXPECTED_SHA="a" * 40)
                result = subprocess.run(["bash", "-c", step_script(name)], cwd=root,
                                        env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                fallback = root / "ci-diagnostics/fallback"
                self.assertEqual((fallback / "arch-bootstrap.log").read_text(), "bootstrap failed\n")
                self.assertIn("Checkout=skipped", (fallback / "stage-outcomes-before-upload.txt").read_text())
                self.assertIn("checkout outcome skipped", (fallback / "collector-unavailable.txt").read_text())

    def test_collector_failure_does_not_discard_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            helper = root / ".github/packaging/archlinux/ci-build.sh"
            helper.parent.mkdir(parents=True)
            helper.write_text("#!/bin/bash\nexit 23\n")
            env = dict(os.environ, RUNNER_TEMP=str(root), CI_CHECKOUT_OUTCOME="success",
                       CI_STAGE_OUTCOMES="Bootstrap=success\nCheckout=success",
                       CDE_SOURCE_REPOSITORY="owner/repo", CDE_EXPECTED_SHA="b" * 40)
            result = subprocess.run(["bash", "-c", step_script(
                "Collect build diagnostics")],
                cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 23)
            self.assertEqual((root / "ci-diagnostics/fallback/collector-exit-status.txt").read_text(), "23\n")
            self.assertTrue((root / "ci-diagnostics/fallback/environment.txt").is_file())
