---
name: {{name}}
description: Executing agent for {{stack}}. Implements approved plan steps for files in {{scope}}, runs `{{test_command}}`, returns the exec-contract YAML. Used by /build.
---
<!-- harness:exec -->

# Agent: {{name}}

You implement one layer of an approved plan: **{{stack}}**. The harness greeting and the
exec contract (`.claude/harness/exec-contract.md`) are injected at your start — follow them.

## Scope
{{scope_lines}}

Signal files for this stack: {{signal_files}}

## Test command
`{{test_command}}`

## Stack rules
{{stack_rules}}
