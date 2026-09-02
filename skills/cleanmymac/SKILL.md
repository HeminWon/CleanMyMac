---
name: cleanmymac
description: Manually-invoked project skill named CleanMyMac for safe macOS developer-environment maintenance utilities. Use only when the user explicitly invokes this skill or directly asks to work on this skill; not the commercial CleanMyMac app and not bound to a single script.
---

# CleanMyMac

## Activation

Use this skill only when explicitly invoked or when the user directly asks to work on this skill. Do not proactively apply it to normal cleanup or refactor requests.

## Goal

Use “CleanMyMac” here as this skill's project-style name, not as a dependency on the commercial CleanMyMac app or as a binding to any single script. Maintain macOS developer environments and recover disk space by managing rebuildable local data: tool caches, logs, simulator assets, package-manager artifacts, and generated intermediates. Preserve user-owned data, configuration, credentials, project indexes, worktrees, prompts, and generated outputs unless explicitly named and confirmed.

## Scope

- Implement maintenance flows in the user's chosen language or app surface.
- Prioritize currently implemented maintenance units. New units may cover Xcode, Homebrew, RubyGems, CocoaPods, AI tool artifacts, caches, logs, Trash, and simulators when requested.
- Do not call, wrap, or depend on the commercial CleanMyMac app.
- Keep runtime behavior self-contained when a utility may be run through a pipe, package manager, or other minimal execution context.

## Safety Contract

Treat deletion, cache pruning, log removal, Trash emptying, and package artifact removal as destructive.

Before destructive behavior:

- Identify the affected maintenance unit.
- Preview affected paths, counts, and estimated sizes where possible.
- Require explicit confirmation before mutation.
- Skip missing optional tools instead of failing the whole run.
- Avoid `sudo` unless necessary; when used, explain why and keep a graceful skip path.
- Avoid broad recursive deletion unless candidates are listed first.

For AI developer-tool artifacts:

- OK by default: rebuildable caches, logs, traces, temporary run directories, and generated intermediate files.
- Never delete unless explicitly named and confirmed: conversation history, prompts, credentials, configuration, indexes, worktrees, and generated user outputs.

## Implementation Defaults

- Implement the smallest focused change.
- Prefer small, named maintenance units with clear terminal or UI status.
- Keep the newest useful versioned developer assets by default and ask before deleting older versions.
- Use macOS-compatible shell behavior; avoid GNU-only flags unless support is detected or a fallback is provided.
- Prefer native macOS/developer tools such as `find`, `du`, `df`, `xcrun`, `osascript`, `brew cleanup`, `pod cache clean`, and `gem cleanup` when they fit.
- For Homebrew maintenance, handle Apple Silicon explicitly when shelling out by routing `brew` commands through `arch -arm64` on `arm64`.
- Use `$HOME/Library/...` path variables and quote paths and variables, especially where directory names contain spaces.
- Keep output human-readable and concise. Warnings should explain what was skipped and why.

## Validation

- For shell implementations, run `bash -n` on changed scripts.
- Run ShellCheck when it is available; if it is not installed, mention that it was skipped.
- For documentation-only or skill-only changes, a quick read-through is enough.
