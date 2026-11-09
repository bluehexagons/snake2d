"""Bash tooling failure contracts; standard library only, no engine required."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="snake tooling café %fixture% ")
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name)
        for name in ("build.sh", "test.sh"):
            shutil.copy2(ROOT / name, self.project / name)
        shutil.copytree(ROOT / "scripts", self.project / "scripts")
        (self.project / "tests").mkdir()
        (self.project / "tests/source-suites.txt").write_text("fixture_test.gd|Fixture passed.\n")
        self.engine = self.project / "fake engine"
        self.engine.write_text('''#!/bin/bash
case "${FIXTURE_MODE:-pass}" in
    fail) echo 'fixture failed' >&2; exit 7;;
    error) echo 'SCRIPT ERROR: fixture' >&2; exit 0;;
    hang) sleep 30; exit;;
    early) exit 0;;
esac
while (( $# )); do
    case "$1" in
        --script) echo 'Fixture passed.';;
        --scene) echo 'Smoke test passed.';;
        --export-release)
            if [[ "${FIXTURE_MODE:-}" != missing-output ]]; then
                printf '#!/bin/bash\\nexit 0\\n' > "$3"
                chmod +x "$3"
            fi
            exit 0;;
    esac
    shift
done
''')
        self.engine.chmod(0o755)
        self.env = os.environ.copy()
        for key in ("GODOT_BIN", "GODOT", "GODOT4", "BASALTWATER_GODOT_EXE", "GODOT_TIMEOUT_SECONDS"):
            self.env.pop(key, None)
        self.env["GODOT_BIN"] = str(self.engine)

    def run_script(self, script="test.sh", mode="source", **env):
        return subprocess.run(["bash", str(self.project / script), mode],
                              env=self.env | env, cwd=self.project,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, timeout=12)

    def test_source_success(self):
        self.assertEqual(self.run_script().returncode, 0)

    def test_failure_contracts(self):
        for mode, message in (("fail", "fixture failed"), ("error", "SCRIPT ERROR"),
                              ("early", "before reporting")):
            with self.subTest(mode=mode):
                result = self.run_script(FIXTURE_MODE=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stdout)

    def test_deadline(self):
        result = self.run_script(FIXTURE_MODE="hang", GODOT_TIMEOUT_SECONDS="1")
        self.assertEqual(result.returncode, 124)
        self.assertIn("deadline 1 seconds", result.stdout)

    def test_invalid_deadline(self):
        for value in ("0", "-1", "abc", "3601", "9999999999999999999"):
            with self.subTest(value=value):
                result = self.run_script(GODOT_TIMEOUT_SECONDS=value)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("integer from 1 to 3600", result.stdout)

    def test_basaltwater_engine_discovery(self):
        self.env.pop("GODOT_BIN")
        self.assertEqual(self.run_script(BASALTWATER_GODOT_EXE=str(self.engine)).returncode, 0)

    def test_explicit_missing_engine_does_not_fall_back(self):
        result = self.run_script(GODOT_BIN=str(self.project / "missing"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Explicit GODOT_BIN", result.stdout)

    def test_build_output_required(self):
        self.assertEqual(self.run_script("build.sh", "linux").returncode, 0)
        result = self.run_script("build.sh", "linux", FIXTURE_MODE="missing-output")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected export output", result.stdout)

    def test_export_runs_outside_checkout_without_editor(self):
        export = self.project / "out/linux64/snake.x86_64"
        export.parent.mkdir(parents=True)
        (self.project / "project.godot").touch()
        export.write_text('#!/bin/bash\n[[ ! -e project.godot ]] || exit 9\n')
        export.chmod(0o755)
        self.assertEqual(self.run_script(mode="linux-export", GODOT_BIN="/missing").returncode, 0)
        export.write_text('#!/bin/bash\necho "ERROR: missing package" >&2\nexit 0\n')
        self.assertNotEqual(self.run_script(mode="linux-export").returncode, 0)


if __name__ == "__main__":
    unittest.main()
