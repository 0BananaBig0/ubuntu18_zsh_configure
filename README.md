# ubuntu18_zsh_configure
ubuntu18_zsh_configure
a personal zsh configure only for using zinit to execute the source commands.

The plugin and its functions require Zsh. Exported environment variables carry
over when starting Bash, but functions and aliases do not.

`add_to_env_var` adds existing directories once, preserving the position of any
entry already present. It accepts `before` (default), `after`, and the existing
Chinese equivalents. Invalid positions and missing directories return failure.

Run the regression checks with Zsh and Python 3 (standard library only):

```sh
python3 tests/test_plugin.py
zsh -n ubuntu18_zsh_configure.plugin.zsh
zsh -n function/function.zsh
```

The tests exercise environment updates, project-root discovery, and optional
startup sections using temporary installation layouts.

To compare root-discovery performance against the committed version before
these optimizations:

```sh
git show 9ff9f1e:function/function.zsh > /tmp/zinit-original-functions.zsh
python3 tests/benchmark_root.py /tmp/zinit-original-functions.zsh function/function.zsh
```

The benchmark uses depths of 5, 25, and 100 directory levels, with 20 lookups
per sample and seven samples per version. It reports median wall time, including
shell launch and function sourcing; it does not measure full plugin startup.

Measured on 2026-10-03 with Zsh 5.9 on x86_64 WSL2/Linux
6.18.33.2-microsoft-standard-WSL2:

| Directory depth | Before, ms/lookup | After, ms/lookup |
| --- | ---: | ---: |
| 5 | 6.43 | 0.71 |
| 25 | 31.68 | 1.57 |
| 100 | 131.17 | 6.45 |
