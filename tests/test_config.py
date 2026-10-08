"""Configuration helpers, tested with isolated paths: python3 tests/test_config.py."""

from pathlib import Path
import subprocess
import tempfile
import unittest

try:
    import tomllib
except ImportError:
    tomllib = None


FUNCTIONS = Path(__file__).resolve().parents[1] / "function/function.zsh"


class ConfigTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix="zinit config ")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.home = self.root / "home"
        self.share = self.root / "share"
        self.backup = self.root / "backup"
        for directory in (self.home, self.share, self.backup):
            directory.mkdir()
        source = FUNCTIONS.read_text(encoding="utf-8").replace(
            "${HOME}", "${PLUGIN_TEST_HOME}"
        ).replace("/usr/share", "${PLUGIN_TEST_SHARE}")
        self.functions = self.root / "functions.zsh"
        self.functions.write_text(source, encoding="utf-8")

    def run_zsh(self, code, *args, succeeds=True, cwd=None):
        result = subprocess.run(
            ["zsh", "-f", "-c",
             'PLUGIN_TEST_HOME="$1"; PLUGIN_TEST_SHARE="$2"; source "$3"; shift 3; ' + code,
             "config-test", str(self.home), str(self.share), str(self.functions), *map(str, args)],
            cwd=cwd, capture_output=True, universal_newlines=True, timeout=5,
        )
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def write(self, path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def parse_toml(self, config):
        try:
            return tomllib.loads(config.read_text())
        except tomllib.TOMLDecodeError as error:
            self.fail("Updated configuration is invalid TOML: " + str(error))

    def test_sparse_linux_backup_and_restore_return_success(self):
        original = self.write(self.home / ".vim/vimrc", "set number\n")
        original.chmod(0o640)
        self.run_zsh('backup_linux_config "$1"', self.backup)
        self.assertEqual((self.backup / "vim/vimrc").read_text(), "set number\n")
        original.unlink()
        self.run_zsh('restore_linux_config "$1"', self.backup)
        self.assertEqual(original.read_text(), "set number\n")
        self.assertEqual(original.stat().st_mode & 0o777, 0o640)

    def test_linux_backup_does_not_hide_an_earlier_copy_failure(self):
        self.write(self.home / ".vim/vimrc", "set number\n")
        self.write(self.home / ".tessent_startup", "# later file\n")
        (self.backup / "vim/vimrc").mkdir(parents=True)
        self.run_zsh('backup_linux_config "$1"', self.backup, succeeds=False)

    def test_linux_fonts_conf_round_trip(self):
        original = self.write(self.home / ".config/fontconfig/fonts.conf", "<fontconfig/>\n")
        original.chmod(0o640)
        self.run_zsh('backup_linux_config "$1"', self.backup)
        self.assertEqual((self.backup / "linux/fonts.conf").read_text(), "<fontconfig/>\n")
        original.unlink()
        (original.parent).rmdir()
        self.run_zsh('restore_linux_config "$1"', self.backup)
        self.assertEqual(original.read_text(), "<fontconfig/>\n")
        self.assertEqual(original.stat().st_mode & 0o777, 0o640)

    def test_linux_restore_does_not_hide_an_earlier_copy_failure(self):
        self.write(self.backup / "vim/vimrc", "set number\n")
        self.write(self.backup / "others/.tessent_startup", "# later file\n")
        (self.home / ".vim/vimrc").mkdir(parents=True)
        self.run_zsh('restore_linux_config "$1"', self.backup, succeeds=False)

    def test_linux_backup_reports_destination_creation_failure(self):
        blocked = self.write(self.root / "blocked", "not a directory\n")
        self.write(self.home / ".tessent_startup", "# fixture\n")
        self.run_zsh('backup_linux_config "$1"', blocked, succeeds=False)

    def test_terminal_backup_and_restore_handle_empty_directories(self):
        (self.home / ".local/share/konsole").mkdir(parents=True)
        self.run_zsh('backup_terminal_config "$1" 5', self.backup)
        self.run_zsh('restore_terminal_config "$1" 5', self.backup)

    def test_terminal_round_trip_keeps_hidden_files_and_links(self):
        original = self.write(self.home / ".local/share/konsole/.hidden-theme", "[General]\n")
        original.chmod(0o640)
        link = original.parent / "theme-link"
        link.symlink_to(".hidden-theme")
        self.run_zsh('backup_terminal_config "$1" 5', self.backup)
        stored = self.backup / "terminal_backup_Qt_5/konsole/share-konsole/.hidden-theme"
        self.assertTrue(stored.is_file())
        self.assertEqual(stored.stat().st_mode & 0o777, 0o640)
        self.assertTrue((stored.parent / "theme-link").is_symlink())
        original.unlink()
        link.unlink()
        self.run_zsh('restore_terminal_config "$1" 5', self.backup)
        self.assertEqual(original.read_text(), "[General]\n")
        self.assertTrue(link.is_symlink())

    def test_konsole_restore_creates_missing_config_directory(self):
        stored = self.backup / "terminal_backup_Qt_5/konsole/konsolerc"
        self.write(stored, "[General]\n")
        self.run_zsh('restore_terminal_config "$1" 5', self.backup)
        self.assertEqual((self.home / ".config/konsolerc").read_text(), "[General]\n")

    def test_terminal_backup_and_restore_report_copy_failures(self):
        self.write(self.home / ".config/konsolerc", "[General]\n")
        self.write(self.home / ".local/share/konsole/theme", "# later file\n")
        destination = self.backup / "terminal_backup_Qt_5/konsole/konsolerc"
        destination.mkdir(parents=True)
        self.run_zsh('backup_terminal_config "$1" 5', self.backup, succeeds=False)
        destination.rmdir()
        self.write(destination, "[General]\n")
        (self.home / ".config/konsolerc").unlink()
        (self.home / ".config/konsolerc").mkdir()
        self.run_zsh('restore_terminal_config "$1" 5', self.backup, succeeds=False)

    def test_copy_helper_reports_success_and_missing_templates(self):
        workspace = self.root / "project"
        workspace.mkdir()
        self.write(self.home / ".vim/.c_cpp/.clangd", "# template\n")
        self.run_zsh('check_and_copy_file "$1" .clangd', workspace)
        self.assertEqual((workspace / ".clangd").read_text(), "# template\n")
        self.run_zsh('check_and_copy_file "$1" missing', workspace, succeeds=False)

    def test_configure_modes_copy_files_and_return_success(self):
        clang = (".clangd", ".clang-format", ".clang-tidy")
        templates = (*clang, ".vscode/launch.json", ".vimspector.json")
        for name in templates:
            self.write(self.home / ".vim/.c_cpp" / name, name + "\n")
        modes = (
            ("clang", clang, False),
            ("vscode", (".vscode/launch.json",), False),
            ("vimspector", (".vimspector.json",), True),
            ("dbg", (".vscode/launch.json", ".vimspector.json"), True),
            ("all", templates, True),
            ("", (*clang, ".vimspector.json"), True),
        )
        for index, (mode, expected_files, opens_editor) in enumerate(modes):
            with self.subTest(mode=mode):
                workspace = self.root / str(index)
                workspace.mkdir()
                (workspace / ".root").touch()
                calls = self.home / "editor-calls"
                if calls.exists():
                    calls.unlink()
                self.run_zsh(
                    'gvim() { print -r -- "$1" >> "$PLUGIN_TEST_HOME/editor-calls"; }; configure "$1"',
                    mode, cwd=workspace,
                )
                for name in expected_files:
                    self.assertEqual((workspace / name).read_text(), name + "\n")
                self.assertEqual(calls.exists(), opens_editor)
                if opens_editor:
                    self.assertEqual(calls.read_text().strip(), str(workspace / ".vimspector.json"))

    def test_configure_does_not_use_or_clear_global_workspace(self):
        self.write(self.home / ".vim/.c_cpp/.vscode/launch.json", "{}\n")
        workspace = self.root / "project"
        workspace.mkdir()
        (workspace / ".root").touch()
        self.run_zsh(
            'workspace_path=sentinel; configure vscode || exit; [[ $workspace_path == sentinel ]]',
            cwd=workspace,
        )
        self.assertEqual((workspace / ".vscode/launch.json").read_text(), "{}\n")

    def test_configure_rejects_invalid_action_without_leaking_state(self):
        self.run_zsh('configure invalid', succeeds=False)
        self.run_zsh('configure invalid >/dev/null 2>&1; [[ -z ${workspace_path+x} ]]')

    def test_configure_preserves_existing_file_and_stops_before_editor_on_copy_failure(self):
        workspace = self.root / "project"
        workspace.mkdir()
        (workspace / ".root").touch()
        target = self.write(workspace / ".vimspector.json", "local settings\n")
        self.write(self.home / ".vim/.c_cpp/.vimspector.json", "template\n")
        self.run_zsh('gvim() { return 0; }; configure vimspector', cwd=workspace)
        self.assertEqual(target.read_text(), "local settings\n")
        target.unlink()
        self.run_zsh(
            'cp() { return 1; }; gvim() { print called > "$PLUGIN_TEST_HOME/editor-calls"; }; configure vimspector',
            succeeds=False, cwd=workspace,
        )
        self.assertFalse((self.home / "editor-calls").exists())

    def test_standard_gcc_lookup_avoids_full_find(self):
        printer = self.write(self.share / "gcc-16/python/libstdcxx/v6/printers.py", "# fixture\n")
        stored = self.write(self.backup / "others/.gdbinit", "sys.path.insert(0, '__GCC_PYTHON_PATH__')\n")
        self.run_zsh('find() { return 1; }; restore_linux_config "$1"', self.backup)
        self.assertEqual((self.home / ".gdbinit").read_text(),
                         "sys.path.insert(0, '" + str(printer.parents[2]) + "')\n")
        self.assertIn("__GCC_PYTHON_PATH__", stored.read_text())

    def test_gcc_lookup_keeps_nonstandard_and_directory_fallbacks(self):
        printer = self.write(self.share / "vendor/gcc-custom/python/libstdcxx/v6/printers.py", "# fixture\n")
        result = self.run_zsh('_find_gcc_python_path')
        self.assertEqual(result.stdout.strip(), str(printer.parents[2]))
        printer.unlink()
        result = self.run_zsh('_find_gcc_python_path')
        self.assertEqual(result.stdout.strip(), str(printer.parents[2]))

    def test_toml_update_replaces_values_preserves_comments_and_mode(self):
        if tomllib is None:
            self.skipTest("TOML validation requires Python 3.11+")
        config = self.write(self.root / "config.toml", '''# keep header
[other]
vim_mode_default = false
 [tui] # keep table comment
  vim_mode_default = false # keep key comment
vim_mode_initial_state = "normal"
vim_mode_after_submit = "normal"
theme = "dracula"
[tui.colors]
vim_mode_default = false
''')
        config.chmod(0o640)
        self.run_zsh('ensure_codex_vim "$1"', config)
        data = self.parse_toml(config)
        self.assertTrue(data["tui"]["vim_mode_default"])
        self.assertEqual(data["tui"]["vim_mode_initial_state"], "insert")
        self.assertEqual(data["tui"]["vim_mode_after_submit"], "insert")
        self.assertEqual(data["tui"]["theme"], "dracula")
        self.assertFalse(data["other"]["vim_mode_default"])
        self.assertFalse(data["tui"]["colors"]["vim_mode_default"])
        self.assertIn("# keep key comment", config.read_text())
        self.assertEqual(config.stat().st_mode & 0o777, 0o640)
        first = config.read_text()
        self.run_zsh('ensure_codex_vim "$1"', config)
        self.assertEqual(config.read_text(), first)

    def test_toml_update_adds_missing_keys_and_repairs_its_duplicates(self):
        if tomllib is None:
            self.skipTest("TOML validation requires Python 3.11+")
        for original in ("[other]\nvalue = 3\n", "[tui]\nvim_mode_default = false\nvim_mode_default = true\n"):
            with self.subTest(original=original):
                config = self.write(self.root / "config.toml", original)
                self.run_zsh('ensure_codex_vim "$1"', config)
                data = self.parse_toml(config)
                self.assertEqual(data["tui"], {
                    "vim_mode_default": True,
                    "vim_mode_initial_state": "insert",
                    "vim_mode_after_submit": "insert",
                })

    def test_toml_write_failure_leaves_existing_file_intact(self):
        config = self.write(self.root / "config.toml", "[tui]\nvim_mode_default = false\n")
        original = config.read_text()
        self.run_zsh('awk() { return 1; }; ensure_codex_vim "$1"', config, succeeds=False)
        self.assertEqual(config.read_text(), original)
        self.assertEqual(list(self.root.glob("config.toml.tmp*")), [])

    def test_toml_update_preserves_multiline_strings_and_arrays(self):
        if tomllib is None:
            self.skipTest("TOML validation requires Python 3.11+")
        config = self.write(self.root / "config.toml", '''prompt = """
[tui]
vim_mode_default = false
"""
[tui]
options = [
    ["inner"]
]
vim_mode_initial_state = """
normal
""" # keep closing comment
''')
        before = tomllib.loads(config.read_text())
        self.run_zsh('ensure_codex_vim "$1"', config)
        after = self.parse_toml(config)
        self.assertEqual(after["prompt"], before["prompt"])
        self.assertEqual(after["tui"]["options"], before["tui"]["options"])
        self.assertEqual(after["tui"]["vim_mode_initial_state"], "insert")
        self.assertIn("# keep closing comment", config.read_text())

    def test_toml_update_handles_crlf_and_quoted_names(self):
        if tomllib is None:
            self.skipTest("TOML validation requires Python 3.11+")
        for original in (
            b"[tui]\r\nvim_mode_default = false\r\n",
            b'["tui"]\n"vim_mode_default" = false\n',
            b"['tui']\n'vim_mode_default' = false\n",
        ):
            with self.subTest(original=original):
                config = self.root / "config.toml"
                config.write_bytes(original)
                self.run_zsh('ensure_codex_vim "$1"', config)
                self.assertEqual(self.parse_toml(config)["tui"], {
                    "vim_mode_default": True,
                    "vim_mode_initial_state": "insert",
                    "vim_mode_after_submit": "insert",
                })

    def test_toml_update_preserves_config_symlink(self):
        target = self.write(self.root / "actual.toml", "[tui]\nvim_mode_default = false\n")
        link = self.root / "config.toml"
        link.symlink_to(target)
        self.run_zsh('ensure_codex_vim "$1"', link)
        self.assertTrue(link.is_symlink())
        self.assertIn("vim_mode_default = true", target.read_text())

    def test_toml_creation_reports_parent_directory_failure(self):
        blocked = self.write(self.root / "blocked", "not a directory\n")
        self.run_zsh('ensure_codex_vim "$1/config.toml"', blocked, succeeds=False)

    def test_toml_update_rejects_directory_as_config_path(self):
        config = self.root / "config.toml"
        config.mkdir()
        self.run_zsh('ensure_codex_vim "$1"', config, succeeds=False)
        self.assertEqual(list(config.iterdir()), [])
        self.assertEqual(list(self.root.glob("config.toml.tmp*")), [])


if __name__ == "__main__":
    unittest.main()
