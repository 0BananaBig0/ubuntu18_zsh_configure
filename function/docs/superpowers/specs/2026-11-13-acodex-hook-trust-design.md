# acodex Hook Trust Design

**Intent:** Stop `acodex` from erasing Codex's profile-specific hook approvals while still picking up deliberate edits to the base configuration.

**Behavior:** `acodex` creates or refreshes `account.config.toml` only when that file is missing or `config.toml` has a newer modification time. On refresh it comments the custom provider line in the copied profile and runs `codex --profile account`. When the profile is newer, it is left untouched so Codex's persisted hook trust survives later launches.

**Scope:** Modify the existing `acodex` shell function and its focused zsh regression test. No new dependencies or TOML parser are needed. A user who wants to force a full resync can delete `account.config.toml` and run `acodex` once.

**Approaches:** A TOML merge would preserve trust while always copying, but it adds fragile shell parsing. Timestamp-gated copying is the smallest complete change and intentionally causes a new trust decision only after a base-config update.
