"""Offline font installation checks: python3 tests/test_install_font.py."""

from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zipfile


SOURCE = Path(__file__).resolve().parents[1] / "function/install_font.zsh"


class FontTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="font's test ")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.script = self.root / "install_font.zsh"
        self.script.write_text(SOURCE.read_text().replace("${HOME}", "${FONT_TEST_HOME}"))
        self.work = self.root / "work"
        self.fonts = self.root / "home/.local/share/fonts"
        self.payload = self.root / "payload"
        self.payload.mkdir()
        for family in ("FantasqueSansMono", "JuliaMono"):
            for weight in ("Regular", "Bold"):
                (self.payload / (family + "-" + weight + ".ttf")).write_text("font fixture")
        with zipfile.ZipFile(self.root / "fixture.zip", "w") as archive:
            for font in self.payload.glob("Fantasque*"):
                archive.write(font, "nested/" + font.name)
        with zipfile.ZipFile(self.root / "julia.zip", "w") as archive:
            for font in self.payload.glob("JuliaMono*"):
                archive.write(font, "nested/" + font.name)
        with tarfile.open(self.root / "fixture.tar.gz", "w:gz") as archive:
            for font in self.payload.glob("JuliaMono*"):
                archive.add(font, "nested/" + font.name)

    def run_zsh(self, code):
        # Keep extraction/copy/permissions real; isolate network, sudo and fontconfig.
        setup = r'''
            source "$1"
            FONT_TEST_ROOT="$2"
            FONT_TEST_HOME="$2/home"
            FONT_USE_SUDO=0
            sudo() { print -u2 -- 'unexpected sudo'; return 99; }
            mktemp() { command mkdir -p "$FONT_TEST_ROOT/work" && print -r -- "$FONT_TEST_ROOT/work"; }
            curl() {
                local url="${@[-3]}" output="${@[-1]}" fixture
                print -r -- "$url" >> "$FONT_TEST_ROOT/urls"
                case "$url" in
                    */FantasqueSansMono.zip) fixture=fixture.zip ;;
                    */JuliaMono-ttf.tar.gz) fixture=fixture.tar.gz ;;
                    */JuliaMono-ttf.zip) fixture=julia.zip ;;
                    *) return 1 ;;
                esac
                command cp "$FONT_TEST_ROOT/$fixture" "$output"
            }
            restorecon() { return 0; }
            fc-cache() { return 0; }
            fc-list() { print -rl -- "$FONT_TEST_HOME/.local/share/fonts"/**/*.ttf(N); }
        '''
        return subprocess.run(
            ["zsh", "-f", "-c", setup + code, "font-test", str(self.script), str(self.root)],
            capture_output=True, text=True, timeout=10,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_finalize_counts_zero_one_two_and_three_matches(self):
        for count in range(4):
            with self.subTest(count=count):
                lines = "\n".join("FantasqueSansMono " + str(i) for i in range(count))
                result = self.run_zsh(
                    'fc-list() { print -r -- "' + lines + '"; }\n'
                    '_font_finalize /tmp/font-test FantasqueSansMono'
                )
                self.assertEqual(result.returncode, 0 if count else 1, result.stdout)
                self.assertEqual("已识别" in result.stdout, bool(count), result.stdout)

    def test_finalize_propagates_cache_and_font_query_failures(self):
        for failure in ("fc-cache", "fc-list", "restorecon"):
            with self.subTest(failure=failure):
                result = self.run_zsh('''
                    fc-list() { print -rl -- 'JuliaMono A' 'JuliaMono B' 'JuliaMono C'; }
                ''' + failure + '''() { print -rl -- 'JuliaMono A' 'JuliaMono B' 'JuliaMono C'; return 1; }
                    _font_finalize /tmp/font-test JuliaMono
                ''')
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_labels_are_repaired_before_refreshing_destination(self):
        result = self.run_zsh('''
            restorecon() { print -r -- restored > "$FONT_TEST_ROOT/labels"; }
            fc-cache() {
                [[ -f "$FONT_TEST_ROOT/labels" && "${@[-1]}" == /tmp/font-test ]] || return 1
                print -r -- refreshed > "$FONT_TEST_ROOT/cache"
            }
            fc-list() { print -rl -- 'JuliaMono A' 'JuliaMono B' 'JuliaMono C'; }
            _font_finalize /tmp/font-test JuliaMono
        ''')
        self.assert_success(result)
        self.assertTrue((self.root / "cache").exists())

    def test_both_installers_copy_regular_fonts_and_cleanup(self):
        for family, function in (("FantasqueSansMono", "install_font_fantasque"), ("JuliaMono", "install_font_juliamono")):
            with self.subTest(family=family):
                result = self.run_zsh(function + " --user --only-regular")
                self.assert_success(result)
                installed = self.fonts / family
                self.assertEqual([p.name for p in installed.iterdir()], [family + "-Regular.ttf"])
                self.assertEqual((installed / (family + "-Regular.ttf")).stat().st_mode & 0o777, 0o644)
                self.assertEqual(installed.stat().st_mode & 0o777, 0o755)
                self.assertFalse(self.work.exists())

    def test_combined_install_routes_version_only_to_fantasque(self):
        result = self.run_zsh("install_font_all --user --only-regular 3.4.0")
        self.assert_success(result)
        self.assertTrue((self.fonts / "JuliaMono/JuliaMono-Regular.ttf").exists())
        self.assertIn("/v3.4.0/FantasqueSansMono.zip", (self.root / "urls").read_text())

    def test_download_failure_returns_to_caller_and_cleans_up(self):
        for function in ("install_font_fantasque", "install_font_juliamono"):
            with self.subTest(function=function):
                result = self.run_zsh('curl() { return 1; }\n' + function + ''' --user
                    result=$?
                    [[ $result != 0 && ! -o errexit ]] || exit 1
                    print -r -- caller-alive
                ''')
                self.assert_success(result)
                self.assertIn("caller-alive", result.stdout)
                self.assertFalse(self.work.exists())

    def test_juliamono_does_not_overwrite_caller_variables(self):
        result = self.run_zsh('''
            asset=original
            install_font_juliamono --user || exit 1
            [[ "$asset" == original ]]
        ''')
        self.assert_success(result)

    def test_temporary_directory_failure_does_not_start_download(self):
        for function in ("install_font_fantasque", "install_font_juliamono"):
            with self.subTest(function=function):
                result = self.run_zsh('''
                    mktemp() { return 1; }
                    curl() { print -r -- download-started; return 1; }
                ''' + function + " --user || exit 3")
                self.assertEqual(result.returncode, 3)
                self.assertNotIn("download-started", result.stdout)

    def test_permission_failures_are_reported(self):
        result = self.run_zsh('''
            chmod() { return 1; }
            _font_install_to "$FONT_TEST_ROOT/destination" "$FONT_TEST_ROOT/payload/JuliaMono-Regular.ttf"
        ''')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_python_zip_fallback_handles_apostrophe_in_path(self):
        binary_dir = self.root / "bin"
        binary_dir.mkdir()
        for name in ("python3", "mkdir", "cp", "rm", "chmod", "chown", "grep", "sort"):
            (binary_dir / name).symlink_to(shutil.which(name))
        result = self.run_zsh('PATH="$FONT_TEST_ROOT/bin"\ninstall_font_fantasque --user --only-regular')
        self.assert_success(result)
        self.assertTrue((self.fonts / "FantasqueSansMono/FantasqueSansMono-Regular.ttf").exists())

    def test_juliamono_uses_zip_when_tar_download_fails(self):
        (self.root / "fixture.tar.gz").unlink()
        result = self.run_zsh("install_font_juliamono --user --only-regular")
        self.assert_success(result)
        self.assertTrue((self.fonts / "JuliaMono/JuliaMono-Regular.ttf").exists())
        self.assertFalse(self.work.exists())

    def test_bad_archives_fail_without_installing_and_cleanup(self):
        for function, archive in (("install_font_fantasque", "fixture.zip"), ("install_font_juliamono", "fixture.tar.gz")):
            with self.subTest(function=function):
                (self.root / archive).write_text("not an archive")
                result = self.run_zsh(function + " --user")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.fonts.exists())
                self.assertFalse(self.work.exists())

    def test_installers_propagate_finalize_failure_when_called_in_condition(self):
        for function in ("install_font_fantasque", "install_font_juliamono", "install_font_all"):
            with self.subTest(function=function):
                result = self.run_zsh('fc-cache() { return 1; }\nif ' + function + ''' --user; then
                    exit 1
                fi
                ''')
                self.assert_success(result)
                self.assertFalse(self.work.exists())

    def test_help_and_invalid_options_have_no_installation_side_effects(self):
        for function in ("install_font_fantasque", "install_font_juliamono", "install_font_all"):
            for option, status in (("--help", 0), ("--invalid", 1)):
                with self.subTest(function=function, option=option):
                    result = self.run_zsh(function + " " + option)
                    self.assertEqual(result.returncode, status)
                    self.assertFalse((self.root / "urls").exists())
                    self.assertFalse(self.work.exists())

    def test_regular_filter_does_not_match_temporary_directory_name(self):
        result = self.run_zsh('''
            mktemp() { command mkdir -p "$FONT_TEST_ROOT/Regular work" && print -r -- "$FONT_TEST_ROOT/Regular work"; }
            install_font_fantasque --user --only-regular
        ''')
        self.assert_success(result)
        self.assertEqual(
            [p.name for p in (self.fonts / "FantasqueSansMono").iterdir()],
            ["FantasqueSansMono-Regular.ttf"],
        )

    def test_codepoint_lookup_reports_fontconfig_failure(self):
        result = self.run_zsh('fc-list() { return 1; }\nfont_who_has U+23fa')
        self.assertNotEqual(result.returncode, 0)

    def prepare_system_install(self):
        # Exercise the non-root branch even when the test runner is root.
        source = self.script.read_text().replace(
            "(( EUID == 0 )) || FONT_USE_SUDO=1", "FONT_USE_SUDO=1"
        ).replace("/usr/share/fonts", "${FONT_TEST_ROOT}/system/fonts")
        self.script.write_text(source)

    def test_system_install_uses_sudo_commands_without_validation(self):
        self.prepare_system_install()
        for family, function in (("FantasqueSansMono", "install_font_fantasque"), ("JuliaMono", "install_font_juliamono")):
            with self.subTest(family=family):
                result = self.run_zsh('''
                    sudo() {
                        case "$1" in
                            mkdir|cp|chown|chmod|restorecon|fc-cache)
                                print -r -- "$1" >> "$FONT_TEST_ROOT/sudo-calls"
                                "$@" ;;
                            *) return 77 ;;
                        esac
                    }
                    chown() { return 0; }
                    fc-list() { print -rl -- "$FONT_TEST_ROOT/system/fonts"/**/*.ttf(N); }
                ''' + function + " --only-regular")
                self.assert_success(result)
                installed = self.root / "system/fonts" / family / (family + "-Regular.ttf")
                self.assertEqual(installed.read_text(), "font fixture")
                self.assertEqual(installed.stat().st_mode & 0o777, 0o644)
                calls = self.root / "sudo-calls"
                self.assertEqual(set(calls.read_text().splitlines()), {"mkdir", "cp", "chown", "chmod", "restorecon", "fc-cache"})
                calls.unlink()
                self.assertFalse(self.work.exists())

    def test_sudo_command_failure_stops_installation_and_cleans_up(self):
        self.prepare_system_install()
        for function in ("install_font_fantasque", "install_font_juliamono"):
            with self.subTest(function=function):
                result = self.run_zsh('sudo() { return 1; }\n' + function)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / "system").exists())
                self.assertFalse(self.work.exists())


if __name__ == "__main__":
    unittest.main()
