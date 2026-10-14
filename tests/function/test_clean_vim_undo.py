import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "function/clean_vim_undo.zsh"


class CleanVimUndoTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="vim undo ")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.vimrc = self.root / ".vim/vimrc"
        self.vimrc.parent.mkdir()
        self.undo = self.root / "undo files"
        self.undo.mkdir()
        self.vimrc.write_text("let &undodir = " + self.vim_string(str(self.undo)) + "\n")

    @staticmethod
    def vim_string(value):
        return "'" + value.replace("'", "''") + "'"

    def file(self, name, age_days, directory=None):
        path = (directory or self.undo) / name
        path.write_text("saved undo history")
        timestamp = time.time() - age_days * 86400
        os.utime(path, (timestamp, timestamp))
        return path

    def run_cleanup(self):
        env = os.environ.copy()
        # Only the child process uses the fixture home; real undo files stay untouched.
        env["HOME"] = str(self.root)
        env.pop("SUDO_USER", None)
        return subprocess.run(
            ["zsh", "-f", "-c", 'source "$1" && clean_vim_undo', "undo-test", str(SCRIPT)],
            env=env, cwd=self.root, capture_output=True, text=True, timeout=10,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")

    def test_only_files_older_than_thirty_days_are_deleted(self):
        old = self.file("old", 30.01)
        recent = self.file("recent", 29.99)
        future = self.file("future", -1)
        hidden = self.file(".old hidden", 40)
        self.assert_success(self.run_cleanup())
        self.assertFalse(old.exists())
        self.assertFalse(hidden.exists())
        self.assertTrue(recent.exists())
        self.assertTrue(future.exists())

    def test_directories_and_symlinks_are_preserved(self):
        nested = self.undo / "nested"
        nested.mkdir()
        nested_file = self.file("old", 50, nested)
        outside = self.file("outside", 50, self.root)
        link = self.undo / "linked undo"
        link.symlink_to(outside)
        self.assert_success(self.run_cleanup())
        self.assertTrue(nested_file.exists())
        self.assertTrue(link.is_symlink())
        self.assertTrue(outside.exists())

    def test_dynamic_vim_setting_is_evaluated(self):
        self.vimrc.write_text(
            "function! s:UserHome() abort\n  return $HOME\nendfunction\n"
            "let &undodir = expand(s:UserHome().'/undo files')\n"
        )
        old = self.file("old", 40)
        self.assert_success(self.run_cleanup())
        self.assertFalse(old.exists())

    def test_multiple_paths_include_escaped_commas(self):
        other = self.root / "undo, second's"
        other.mkdir()
        old = self.file("old", 40)
        other_old = self.file("old\nwith newline", 40, other)
        setting = str(self.undo) + "," + str(other).replace(",", "\\,")
        self.vimrc.write_text("let &undodir = " + self.vim_string(setting) + "\n")
        self.assert_success(self.run_cleanup())
        self.assertFalse(old.exists())
        self.assertFalse(other_old.exists())

    def test_missing_directory_and_empty_directory_are_harmless(self):
        setting = str(self.root / "missing") + "," + str(self.undo)
        self.vimrc.write_text("let &undodir = " + self.vim_string(setting) + "\n")
        self.assert_success(self.run_cleanup())

    def test_directory_names_are_not_expanded_as_wildcards(self):
        literal = self.root / "undo[1]"
        literal.mkdir()
        unrelated = self.root / "undo1"
        unrelated.mkdir()
        old = self.file("old", 40, literal)
        unrelated_old = self.file("old", 40, unrelated)
        self.vimrc.write_text("let &undodir = " + self.vim_string(str(literal)) + "\n")
        self.assert_success(self.run_cleanup())
        self.assertFalse(old.exists())
        self.assertTrue(unrelated_old.exists())

    def test_spaces_after_commas_are_ignored(self):
        other = self.root / "second"
        other.mkdir()
        old = self.file("old", 40, other)
        setting = str(self.undo) + ", " + str(other)
        self.vimrc.write_text("let &undodir = " + self.vim_string(setting) + "\n")
        self.assert_success(self.run_cleanup())
        self.assertFalse(old.exists())

    def test_literal_backslashes_do_not_select_a_different_directory(self):
        for name in ("back\\slash", "back\\\\slash", "back\\ space"):
            with self.subTest(name=name):
                literal = self.root / name
                literal.mkdir()
                unrelated = self.root / name.replace("\\", "")
                unrelated.mkdir(exist_ok=True)
                old = self.file("old", 40, literal)
                unrelated_old = self.file("old", 40, unrelated)
                self.vimrc.write_text("let &undodir = " + self.vim_string(str(literal)) + "\n")
                self.assert_success(self.run_cleanup())
                self.assertFalse(old.exists())
                self.assertTrue(unrelated_old.exists())

    def test_set_expands_tilde_and_environment_variables(self):
        for setting in ("~/undo\\ files", "$HOME/undo\\ files"):
            with self.subTest(setting=setting):
                old = self.file("old", 40)
                self.vimrc.write_text("set undodir=" + setting + "\n")
                self.assert_success(self.run_cleanup())
                self.assertFalse(old.exists())

    def test_unset_or_empty_undodir_is_an_error(self):
        for config in ('" no undo setting\n', "set undodir=\n"):
            with self.subTest(config=config):
                self.vimrc.write_text(config)
                self.assertNotEqual(self.run_cleanup().returncode, 0)

    def test_invalid_vimrc_does_not_delete_files(self):
        old = self.file("old", 40)
        with self.vimrc.open("a") as config:
            config.write("ThisIsNotAVimCommand\n")
        self.assertNotEqual(self.run_cleanup().returncode, 0)
        self.assertTrue(old.exists())

    def test_missing_vimrc_is_an_error(self):
        self.vimrc.unlink()
        self.assertNotEqual(self.run_cleanup().returncode, 0)

    def test_unsafe_paths_fail_before_any_deletion(self):
        old = self.file("old", 40)
        for unsafe in (".", "/", str(self.root)):
            with self.subTest(unsafe=unsafe):
                setting = str(self.undo) + "," + unsafe
                self.vimrc.write_text("let &undodir = " + self.vim_string(setting) + "\n")
                self.assertNotEqual(self.run_cleanup().returncode, 0)
                self.assertTrue(old.exists())


if __name__ == "__main__":
    unittest.main()
