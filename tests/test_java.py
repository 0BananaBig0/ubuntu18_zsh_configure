"""Check Java matching with local fixtures: python3 tests/test_java.py."""

from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


FUNCTIONS = Path(__file__).resolve().parents[1] / "function/function.zsh"


class JavaTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="zinit java ")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.jvm = self.root / "jvm"
        self.source = FUNCTIONS.read_text(encoding="utf-8").replace(
            "/usr/lib/jvm", shlex.quote(str(self.jvm))
        )

    def java(self, home, output, exit_code=0, nested=False):
        binary = home / ("jre/bin/java" if nested else "bin/java")
        binary.parent.mkdir(parents=True, exist_ok=True)
        binary.write_text(
            "#!/bin/sh\n[ \"$1\" = -version ] || exit 2\n"
            + "printf 'called\\n' >> " + shlex.quote(str(home / "invocations")) + "\n"
            + "printf '%s\\n' " + shlex.quote(output) + " >&2\n"
            + "exit " + str(exit_code) + "\n"
        )
        binary.chmod(0o755)
        return binary

    def run_function(self, function, expected_status=0, java_bin=None):
        code = self.source + "\n"
        if java_bin:
            code += 'PATH="$1:$PATH"\n'
        result = subprocess.run(
            ["zsh", "-f", "-c", code + function, "java-test",
             str(java_bin.parent) if java_bin else ""],
            capture_output=True, universal_newlines=True, timeout=5,
        )
        self.assertEqual(result.returncode, expected_status, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout.strip()

    def test_current_java_version_formats(self):
        for output, status in (
            ('openjdk version "1.8.0_452"\nOpenJDK Runtime Environment', 1),
            ('java version "1.8.0_402"', 1),
            ('openjdk version "11.0.27" 2025-04-15', 0),
            ('openjdk version "17.0.15" 2025-04-15', 0),
            ('openjdk version "21" 2023-09-19', 0),
            ('openjdk version "21.0.7+6-LTS"', 0),
            ('openjdk version "25-ea"', 0),
            ('openjdk 25.0.1 2025-10-21', 0),
            ('java version "garbage" 2025-04-15', 1),
            ('java version "8.0.1"\nother component 99.0', 1),
        ):
            with self.subTest(output=output):
                binary = self.java(self.root / "active", output)
                self.run_function("_check_java_version", status, binary)

    def test_failed_java_command_is_not_accepted(self):
        binary = self.java(self.root / "active", 'openjdk version "21.0.7"', exit_code=1)
        self.run_function("_check_java_version", 1, binary)

    def test_distribution_layouts_keep_original_alias_paths(self):
        layouts = (
            ("Fedora", "java-17-openjdk", "java-21-openjdk", "jre-openjdk", "jre-openjdk"),
            ("Rocky", "java-1.8.0-openjdk", "java-17-openjdk", "jre-17-openjdk", "jre-17-openjdk"),
            ("Ubuntu", "java-11-openjdk-amd64", "java-21-openjdk-amd64", "default-java", "java-21-openjdk-amd64"),
        )
        for distro, older, newer, alias, expected in layouts:
            with self.subTest(distribution=distro):
                jvm = self.jvm / distro
                self.source = FUNCTIONS.read_text(encoding="utf-8").replace(
                    "/usr/lib/jvm", shlex.quote(str(jvm))
                )
                self.java(jvm / older, 'openjdk version "1.8.0_452"')
                self.java(jvm / newer, 'openjdk version "21.0.7"')
                (jvm / alias).symlink_to(jvm / newer, target_is_directory=True)
                self.assertEqual(self.run_function("_find_latest_jdk"), str(jvm / expected))

    def test_discovery_compares_versions_instead_of_release_dates(self):
        self.java(self.jvm / "java-11", 'openjdk version "11.0.27" 2026-01-01')
        self.java(self.jvm / "java-21", 'openjdk version "21.0.7" 2025-01-01')
        self.assertEqual(self.run_function("_find_latest_jdk"), str(self.jvm / "java-21"))

    def test_latest_real_directory_keeps_priority(self):
        latest = self.jvm / "java-latest"
        latest.mkdir(parents=True)
        self.java(self.jvm / "java-21", 'openjdk version "21.0.7"')
        self.assertEqual(self.run_function("_find_latest_jdk"), str(latest))

    def test_latest_symlink_keeps_original_fallback_behavior(self):
        older = self.jvm / "java-17"
        self.java(older, 'openjdk version "17.0.15"')
        self.java(self.jvm / "java-21", 'openjdk version "21.0.7"')
        (self.jvm / "java-latest").symlink_to(older, target_is_directory=True)
        self.assertEqual(self.run_function("_find_latest_jdk"), str(self.jvm / "java-21"))

    def test_aliases_launch_once_and_keep_last_matching_path(self):
        home = self.jvm / "java-17"
        self.java(home, 'openjdk version "17.0.15"', nested=True)
        for name in ("jre", "jre-17", "jre-openjdk"):
            (self.jvm / name).symlink_to(home, target_is_directory=True)
        self.assertEqual(self.run_function("_find_latest_jdk"), str(self.jvm / "jre-openjdk"))
        self.assertEqual((home / "invocations").read_text().splitlines(), ["called"])

    def test_version_order_retains_update_and_build_suffixes(self):
        for name, version in (
            ("java-8a", "1.8.0_402"), ("java-8b", "1.8.0_452"),
            ("java-21a", "21.0.9+9"), ("java-21b", "21.0.10+6-LTS"),
        ):
            self.java(self.jvm / name, 'openjdk version "' + version + '"')
        self.assertEqual(self.run_function("_find_latest_jdk"), str(self.jvm / "java-21b"))

    def test_release_metadata_does_not_override_java_output(self):
        home = self.jvm / "java-17"
        self.java(home, 'openjdk version "17.0.15"')
        (home / "release").write_text('JAVA_VERSION="99.0.0"\n')
        self.java(self.jvm / "java-21", 'openjdk version "21.0.7"')
        self.assertEqual(self.run_function("_find_latest_jdk"), str(self.jvm / "java-21"))

    def test_missing_or_empty_jvm_directory_returns_failure_without_output(self):
        self.assertEqual(self.run_function("_find_latest_jdk", 1), "")
        self.jvm.mkdir()
        self.assertEqual(self.run_function("_find_latest_jdk", 1), "")

    def test_caller_shell_options_are_preserved(self):
        binary = self.java(self.root / "active", 'openjdk version "21.0.7"')
        self.run_function(
            'setopt bash_rematch shwordsplit; _check_java_version || exit; '
            '[[ -o bash_rematch && -o shwordsplit ]]', java_bin=binary,
        )


if __name__ == "__main__":
    unittest.main()
