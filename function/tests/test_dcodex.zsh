#!/usr/bin/env zsh
set -eu

repo_root="${0:A:h:h}"
test_root="$(mktemp -d /tmp/dcodex-test.XXXXXXXX)"
trap 'rm -rf -- "$test_root"' EXIT

codex_home="$test_root/codex"
fake_bin="$test_root/bin"
mkdir -p -- "$codex_home" "$fake_bin"

cat > "$codex_home/config.toml" <<'EOF'
model_provider = "custom"
model = "gpt-5.5" # keep me
[profile]
name = "token"
EOF
cp -- "$codex_home/config.toml" "$test_root/config.before"

cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env zsh
for arg in "$@"; do
    print -r -- "$arg"
done > "$DCODEX_ARGS"
EOF
chmod +x "$fake_bin/codex"

DCODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; dcodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/config.toml")" == "$(<"$test_root/config.before")" ]]
[[ "$(<"$codex_home/deepseek.config.toml")" == $'model_provider = "custom"\nmodel = "deepseek-flash" # keep me\n[profile]\nname = "token"' ]]
[[ "$(<"$test_root/args")" == $'--profile\ndeepseek\n--foo\nbar' ]]

print -r -- 'hook trust marker' >> "$codex_home/deepseek.config.toml"
touch -d '2030-01-01 00:00:00' "$codex_home/deepseek.config.toml"
DCODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; dcodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/deepseek.config.toml")" == *'hook trust marker'* ]]

print -r -- 'name = "updated"' >> "$codex_home/config.toml"
touch -d '2040-01-01 00:00:00' "$codex_home/config.toml"
DCODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; dcodex --foo bar' _ "$repo_root"

[[ "$(<"$codex_home/deepseek.config.toml")" == $'model_provider = "custom"\nmodel = "deepseek-flash" # keep me\n[profile]\nname = "token"\nname = "updated"' ]]
[[ "$(<"$codex_home/deepseek.config.toml")" != *'hook trust marker'* ]]

cat > "$codex_home/config.toml" <<'EOF'
model = 'gpt-5.5'
EOF
touch -d '2050-01-01 00:00:00' "$codex_home/config.toml"
DCODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; dcodex' _ "$repo_root"

[[ "$(<"$codex_home/deepseek.config.toml")" == 'model = "deepseek-flash"' ]]

cat > "$codex_home/config.toml" <<'EOF'
model = """gpt-5.5"""
EOF
touch -d '2060-01-01 00:00:00' "$codex_home/config.toml"
if DCODEX_ARGS="$test_root/args" CODEX_HOME="$codex_home" PATH="$fake_bin:$PATH" \
    zsh -c 'source "$1/function.zsh"; dcodex' _ "$repo_root" 2>/dev/null; then
    print -r -- 'dcodex accepted a triple-quoted model' >&2
    exit 1
fi

[[ "$(<"$codex_home/deepseek.config.toml")" == 'model = "deepseek-flash"' ]]
