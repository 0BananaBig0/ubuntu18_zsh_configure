# acodex Hook Trust Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve `acodex` hook trust across launches while refreshing its account profile after a newer base configuration.

**Architecture:** Keep the existing account profile file as the persistence boundary. Gate the existing copy-and-comment operation on file existence and modification time, then keep invoking Codex with the account profile.

**Tech Stack:** zsh shell function, zsh assertions, POSIX file timestamps.

**Spec:** `docs/superpowers/specs/2026-11-13-acodex-hook-trust-design.md`

## Global Constraints

- Use the existing `acodex` function and focused test.
- Do not add dependencies or a TOML parser.
- Preserve hook state when the profile is newer; refresh when `config.toml` is newer or the profile is absent.
- Keep account mode and `codex --profile account` behavior unchanged.

## Review Focus

- Missing profile: the first launch creates and edits the profile.
- Newer profile: a second launch preserves an existing hook-trust marker.
- Newer base config: a later base update refreshes the profile and removes stale profile content.
- Shared config safety: `config.toml` remains unchanged.
- Argument forwarding: extra `acodex` arguments still reach `codex --profile account`.

### Task 1: Timestamp-gated account profile

**Files:**
- Modify: `function/function.zsh:640-653`
- Test: `function/tests/test_acodex.zsh`

**Interfaces:**
- Consumes: `CODEX_HOME/config.toml` and `CODEX_HOME/account.config.toml`.
- Produces: an account profile refreshed only when missing or older than the base config, then `codex --profile account "$@"`.

- [ ] **Step 1: Update the focused zsh test**

  Exercise three launches: create a missing profile; preserve a newer profile containing a `hook trust marker`; then make the base config newer and assert that the profile refreshes, comments `model_provider`, and drops the stale marker. Assert the shared config and forwarded arguments remain correct.

- [ ] **Step 2: Run the focused test and verify the old implementation fails**

  Run: `tests/test_acodex.zsh`
  Expected: FAIL because the current unconditional `cp -f` removes the marker.

- [ ] **Step 3: Implement the timestamp gate**

  In `acodex`, run the existing copy and `sed` only when `account.config.toml` is absent or `config.toml` is newer (`[[ ! -e "$account_config" || "$config" -nt "$account_config" ]]`). Keep the existing error checks and Codex invocation.

- [ ] **Step 4: Run verification**

  Run: `zsh -n function.zsh tests/test_acodex.zsh && tests/test_acodex.zsh`
  Expected: both syntax checks and the focused regression test pass.

- [ ] **Step 5: Review the final diff**

  Run: `git diff --check && git diff -- function.zsh tests/test_acodex.zsh docs/superpowers/specs/2026-11-13-acodex-hook-trust-design.md docs/superpowers/plans/2026-11-13-acodex-hook-trust.md`
  Expected: only the timestamp gate, its regression assertions, and the two workflow documents are changed.
