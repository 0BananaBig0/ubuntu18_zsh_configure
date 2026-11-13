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

print -r -- 'hook trust marker' >> "$codex_home/account.config.toml"
touch -d '2030-01-01 00:00:00' "$codex_home/account.config.toml"
ACODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; acodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/account.config.toml")" == *'hook trust marker'* ]]

print -r -- 'name = "updated"' >> "$codex_home/config.toml"
touch -d '2040-01-01 00:00:00' "$codex_home/config.toml"
ACODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; acodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/account.config.toml")" == $'# model_provider = "custom"\n[profile]\nname = "token"\nname = "updated"' ]]
[[ "$(<"$codex_home/account.config.toml")" != *'hook trust marker'* ]]
