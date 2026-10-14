import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "function/clean_vim_undo.zsh"


class WeeklyUndoTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix="weekly undo ")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.vimrc = self.root / ".vim/vimrc"
        self.vimrc.parent.mkdir()
        self.vimrc.write_text('" fixture\n')
        self.state = self.root / "state/ubuntu18_zsh_configure"
        self.stamp = self.state / "vim-undo-cleanup"
        self.calls = self.root / "calls"
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.root), XDG_STATE_HOME=str(self.root / "state"))
        self.env.pop("SUDO_USER", None)

    def command(self, cleanup="return 0", interactive=True):
        code = '''
            source "$1" || exit
            UNDO_WEEKLY_TEST_CALLS="$2"
            clean_vim_undo() {
                print -r -- called >> "$UNDO_WEEKLY_TEST_CALLS"
        ''' + cleanup + '''
            }
            _clean_vim_undo_weekly
        '''
        return ["zsh", "-fic" if interactive else "-fc", code,
                "weekly-test", str(SCRIPT), str(self.calls)]

    def run_scheduler(self, cleanup="return 0", interactive=True):
        result = subprocess.run(
            self.command(cleanup, interactive), env=self.env,
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        return result

    def call_count(self):
        return len(self.calls.read_text().splitlines()) if self.calls.exists() else 0

    def stamp_age(self, seconds):
        self.state.mkdir(parents=True, exist_ok=True)
        self.stamp.touch()
        timestamp = time.time() - seconds
        os.utime(self.stamp, (timestamp, timestamp))

    def test_first_launch_runs_once_across_subsequent_shells(self):
        self.run_scheduler()
        self.assertEqual(self.call_count(), 1)
        self.assertTrue(self.stamp.is_file())
        self.run_scheduler()
        self.assertEqual(self.call_count(), 1)

    def test_seven_day_cutoff_uses_elapsed_seconds(self):
        self.stamp_age(604740)
        self.run_scheduler()
        self.assertEqual(self.call_count(), 0)
        self.stamp_age(604860)
        self.run_scheduler()
        self.assertEqual(self.call_count(), 1)
        self.assertLess(time.time() - self.stamp.stat().st_mtime, 5)

    def test_failed_cleanup_is_retried_on_next_launch(self):
        self.run_scheduler("return 1")
        self.assertEqual(self.call_count(), 1)
        self.assertFalse(self.stamp.exists())
        self.run_scheduler()
        self.assertEqual(self.call_count(), 2)
        self.assertTrue(self.stamp.exists())

    def test_noninteractive_shells_and_missing_vimrc_are_skipped(self):
        self.run_scheduler(interactive=False)
        self.vimrc.unlink()
        self.run_scheduler()
        self.assertEqual(self.call_count(), 0)
        self.assertFalse(self.state.exists())

    def test_simultaneous_launches_run_only_one_cleanup(self):
        processes = [subprocess.Popen(
            self.command("sleep 0.4; return 0"), env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        ) for _ in range(8)]
        results = [process.communicate(timeout=10) for process in processes]
        for process, (output, errors) in zip(processes, results):
            self.assertEqual(process.returncode, 0, errors)
            self.assertEqual(output, "")
        self.assertEqual(self.call_count(), 1)
        self.assertTrue(self.stamp.exists())

    def test_slow_cleanup_does_not_block_shell_startup(self):
        process = subprocess.Popen(
            self.command("sleep 0.8; return 0"), env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        try:
            self.assertEqual(process.wait(timeout=0.5), 0)
        finally:
            # Wait for the detached worker before removing its fixture directories.
            deadline = time.monotonic() + 3
            while not self.stamp.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(self.stamp.exists())

    def test_filesystem_checks_run_in_the_background_worker(self):
        trace = self.root / "checks"
        code = r'''
            source "$1" || exit
            zmodload zsh/system || exit
            UNDO_WEEKLY_TEST_TRACE="$2"
            print -r -- "$sysparams[pid]"
            TRAPDEBUG() {
                local test_command="${ZSH_DEBUG_CMD%%$'\n'*}"
                if [[ "$test_command" == *vimrc* || "$test_command" == *Nms-* ]]; then
                    print -r -- "$sysparams[pid] $test_command" >> "$UNDO_WEEKLY_TEST_TRACE"
                fi
                return 0
            }
            clean_vim_undo() { return 0; }
            _clean_vim_undo_weekly
        '''
        result = subprocess.run(
            ["zsh", "-fic", code, "weekly-test", str(SCRIPT), str(trace)],
            env=self.env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        events = trace.read_text().splitlines()
        self.assertTrue(any("vimrc" in event for event in events))
        self.assertTrue(any("Nms-" in event for event in events))
        caller_pid = result.stdout.strip()
        self.assertTrue(all(event.split(" ", 1)[0] != caller_pid for event in events), events)

    def test_default_state_directory_is_under_home(self):
        self.env.pop("XDG_STATE_HOME")
        self.run_scheduler()
        self.assertTrue((self.root / ".local/state/ubuntu18_zsh_configure/vim-undo-cleanup").exists())

    def test_plugin_startup_calls_the_real_cleanup(self):
        undo = self.root / "undo"
        undo.mkdir()
        self.vimrc.write_text("let &undodir = '" + str(undo).replace("'", "''") + "'\n")
        old = undo / "old"
        old.write_text("undo history")
        timestamp = time.time() - 40 * 86400
        os.utime(old, (timestamp, timestamp))
        bootstrap = self.root / "plugin.zsh"
        bootstrap.write_text((REPO / "ubuntu18_zsh_configure.plugin.zsh").read_text().split(
            "# Initialize some envs", 1,
        )[0])
        (self.root / "function").symlink_to(REPO / "function", target_is_directory=True)
        result = subprocess.run(
            ["zsh", "-fic", 'source "$1"', "plugin-test", str(bootstrap)],
            env=self.env, capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertFalse(old.exists())
        self.assertTrue(self.stamp.exists())


if __name__ == "__main__":
    unittest.main()
