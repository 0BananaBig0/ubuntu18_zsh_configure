"""Run with python3 tests/test_plugin.py; requires Zsh, no Python packages."""

from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
FUNCTIONS = REPO / "function/function.zsh"
PLUGIN = REPO / "ubuntu18_zsh_configure.plugin.zsh"


class PluginTests(unittest.TestCase):
    def run_zsh(self, code, *args, cwd=None):
        result = subprocess.run(
            ["zsh", "-f", "-c", 'source "$1"; shift; ' + code,
             "plugin-test", str(FUNCTIONS), *map(str, args)],
            cwd=cwd, capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertEqual(result.stderr, "")
        return result.stdout.strip()

    def startup_sections(self, only=None):
        # Execute actual optional-installation blocks, redirecting their paths
        # into a temporary layout rather than sourcing personal startup files.
        text = PLUGIN.read_text()
        sections = []
        for start, end in (
            ("# Qt6 settings\n", "# Mentor  settings\n"),
            ("# Mentor  settings\n", "# Synopsys settings\n"),
            ("# Synopsys settings\n", "# Alias pip3\n"),
            ("# Alias pip3\n", "# Ruby and rbenv configuration\n"),
            ("# Set env for eda-rocky8\n", None),
        ):
            if only and start != only:
                continue
            section = text.split(start, 1)[1]
            sections.append(section.split(end, 1)[0] if end else section)
        return "\n".join(sections).replace(
            "${HOME}", "${TEST_PREFIX}/home"
        ).replace("/EDA/", "${TEST_PREFIX}/EDA/").replace(
            "/data/", "${TEST_PREFIX}/data/"
        )

    def test_duplicate_path_is_unchanged_and_exported(self):
        output = self.run_zsh('''
            PLUGIN_TEST_ENV=/usr/bin
            repeat 1000 { add_to_env_var PLUGIN_TEST_ENV /usr/bin || exit; }
            command zsh -f -c 'print -r -- "$PLUGIN_TEST_ENV"'
        ''')
        self.assertEqual(output, "/usr/bin")

    def test_path_order_and_literal_matching(self):
        with tempfile.TemporaryDirectory(prefix="zinit paths ") as scratch:
            root = Path(scratch)
            for name in ("a", "b", "a*", "ab"):
                (root / name).mkdir()
            output = self.run_zsh('''
                PLUGIN_TEST_ENV="$1/a"
                add_to_env_var PLUGIN_TEST_ENV "$1/b" 后 || exit
                add_to_env_var PLUGIN_TEST_ENV "$1/ab" 前 || exit
                add_to_env_var PLUGIN_TEST_ENV "$1/a*" before || exit
                print -r -- "$PLUGIN_TEST_ENV"
            ''', root)
            self.assertEqual(output, ":".join(str(root / n) for n in ("a*", "ab", "a", "b")))

    def test_invalid_position_does_not_change_empty_variable(self):
        self.run_zsh('''
            unset PLUGIN_TEST_ENV
            add_to_env_var PLUGIN_TEST_ENV /usr/bin invalid && exit 1
            [[ -z ${PLUGIN_TEST_ENV+x} ]]
        ''')

    def test_missing_directory_does_not_change_variable(self):
        with tempfile.TemporaryDirectory() as scratch:
            self.run_zsh('''
                PLUGIN_TEST_ENV=/usr/bin
                add_to_env_var PLUGIN_TEST_ENV "$1/missing" && exit 1
                [[ $PLUGIN_TEST_ENV == /usr/bin ]]
            ''', scratch)

    def test_root_discovery_needs_no_external_commands(self):
        with tempfile.TemporaryDirectory(prefix="zinit root ") as scratch:
            root = Path(scratch)
            (root / ".root").touch()
            nested = root / "a/b/c"
            nested.mkdir(parents=True)
            output = self.run_zsh('PATH=""; dirname() { print -r -- /; }; find_root_path', cwd=nested)
            self.assertEqual(output, str(root))
            (root / "a/.git").write_text("gitdir: elsewhere\n")
            self.assertEqual(self.run_zsh("find_root_path", cwd=nested), str(root / "a"))

    def test_root_fallback_returns_current_directory_and_failure(self):
        output = self.run_zsh('''
            cd / || exit
            result=$(find_root_path 2>/dev/null)
            [[ $? == 1 && $result == / ]]
            print -r -- "$result"
        ''')
        self.assertEqual(output, "/")

    def test_optional_installations_can_have_no_matching_directories(self):
        with tempfile.TemporaryDirectory() as scratch:
            root = Path(scratch)
            for name in ("home/.Qt6", "EDA/Mentor", "EDA/Synopsys", "data/bosios/nvm", "data/bosios/node_modules"):
                (root / name).mkdir(parents=True)
            for heading in ("# Qt6 settings\n", "# Mentor  settings\n", "# Synopsys settings\n", "# Alias pip3\n", "# Set env for eda-rocky8\n"):
                with self.subTest(section=heading.strip()):
                    output = self.run_zsh('TEST_PREFIX="$1"; setopt extended_glob\n' + self.startup_sections(only=heading) + '\nprint -r -- loaded', root)
                    self.assertEqual(output, "loaded")

    def test_node_selection_uses_numeric_order_and_real_installation_path(self):
        with tempfile.TemporaryDirectory(prefix="zinit node ") as scratch:
            root = Path(scratch)
            versions = root / "data/bosios/nvm/versions/node"
            for version in ("v9.0.0", "v22.2.0", "v22.12.0"):
                (versions / version / "bin").mkdir(parents=True)
            output = self.run_zsh(
                'TEST_PREFIX="$1"; setopt extended_glob\n' + self.startup_sections(only="# Set env for eda-rocky8\n")
                + '\n[[ ":$PATH:" == *":$NODE_PATH/bin:"* ]] || exit 1\nprint -r -- "$NODE_PATH"',
                root,
            )
            self.assertEqual(output, str(versions / "v22.12.0"))

    def test_populated_startup_sections_keep_tools_without_duplicate_paths(self):
        with tempfile.TemporaryDirectory(prefix="zinit tools ") as scratch:
            root = Path(scratch)
            tool_dirs = (
                "home/.Qt6/6.8.3/gcc_64/bin",
                "EDA/Mentor/calibre/bin",
                "EDA/Synopsys/vcs/vcs/bin",
                "data/bosios/tools/bin",
                "data/bosios/node_modules/example/bin",
                "data/bosios/node_modules/.bin",
            )
            for name in (*tool_dirs, "home/.local/lib/python3.12/site-packages/pip"):
                (root / name).mkdir(parents=True)
            code = self.startup_sections()
            output = self.run_zsh(
                'TEST_PREFIX="$1"; setopt extended_glob\n' + code + code
                + '\nprint -r -- "$PATH"', root,
            )
            entries = output.split(":")
            for name in tool_dirs:
                self.assertEqual(entries.count(str(root / name)), 1, name)

    def test_startup_follows_symlinked_installation_directories(self):
        with tempfile.TemporaryDirectory(prefix="zinit symlinks ") as scratch:
            root = Path(scratch)
            links = (
                "home/.Qt6/6.8.3/gcc_64",
                "EDA/Mentor/calibre/bin",
                "EDA/Synopsys/vcs/vcs/bin",
                "home/.local/lib/python3.12/site-packages",
                "data/bosios/tools",
                "data/bosios/node_modules/example",
                "data/bosios/nvm/versions/node/v22.12.0",
            )
            for index, name in enumerate(links):
                target = root / "targets" / str(index)
                (target / "bin").mkdir(parents=True)
                (target / "pip").mkdir()
                link = root / name
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to(target, target_is_directory=True)
            output = self.run_zsh(
                'TEST_PREFIX="$1"; setopt extended_glob\n' + self.startup_sections()
                + '\nprint -r -- "$PATH"\nprint -r -- "$NODE_PATH"', root,
            ).splitlines()
            self.assertEqual(len(output), 2, "Node installation was not selected")
            entries = output[0].split(":")
            for name in (links[0] + "/bin", links[1], links[2], links[4] + "/bin", links[5] + "/bin", links[6] + "/bin"):
                with self.subTest(directory=name):
                    self.assertIn(str(root / name), entries)
            self.assertEqual(output[1], str(root / links[6]))
            self.run_zsh(
                'TEST_PREFIX="$1"; ' + self.startup_sections(only="# Alias pip3\n")
                + '\n(( $+aliases[pip] ))', root,
            )


if __name__ == "__main__":
    unittest.main()
