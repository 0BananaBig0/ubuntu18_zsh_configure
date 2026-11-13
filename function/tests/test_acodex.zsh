#!/usr/bin/env zsh
set -eu

repo_root="${0:A:h:h}"
test_root="$(mktemp -d /tmp/acodex-test.XXXXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

codex_home="$test_root/codex"
fake_bin="$test_root/bin"
mkdir -p -- "$codex_home" "$fake_bin"

cat > "$codex_home/config.toml" <<'EOF'
model_provider = "custom"
[profile]
name = "token"
EOF
cp -- "$codex_home/config.toml" "$test_root/config.before"
print -r -- 'stale account config' > "$codex_home/account.config.toml"

cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env zsh
for arg in "$@"; do
    print -r -- "$arg"
done > "$ACODEX_ARGS"
EOF
chmod +x "$fake_bin/codex"

ACODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; acodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/config.toml")" == "$(<"$test_root/config.before")" ]]
[[ "$(<"$codex_home/account.config.toml")" == $'# model_provider = "custom"\n[profile]\nname = "token"' ]]
[[ "$(<"$test_root/args")" == $'--profile\naccount\n--foo\nbar' ]]
