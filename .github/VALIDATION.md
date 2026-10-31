---
title: Validate community-default source changes
description: Check committed source files without requiring a PR template.
---

# Validate community-default source changes

`Organization defaults validation` checks pull requests to `main` in the
special public `MSXOrg/.github` source repository.

## Before starting

Use PowerShell 7.4+, Git, and Node.js/npm. Fetch the intended base and commit
the changes being checked; the validator rejects staged, unstaged, or untracked
differences rather than certifying working-tree corrections as the committed head.
The existing runner restores pinned Pester 6.1.0 and verifies its module GUID.
Markdown validation restores the existing markdownlint-cli2 tool at 0.24.0.

PR descriptions follow the [canonical PR-format guidance][pr-format].
PR templates are intentionally absent: this check neither requires nor copies,
generates, or compares a template scaffold. Other community defaults retain
their ordinary GitHub inheritance behavior. Consumer repositories do not install
this workflow or copy policy/contribution files to satisfy it.

## Steps

1. Fetch the intended base with `git fetch origin main`.
2. Run the anonymous regression suites:

   ```powershell
   pwsh -NoProfile -File .github\scripts\Invoke-PesterSuite.ps1 -Path .github\tests -RequiredVersion 6.1.0
   ```

3. Validate the actual committed inputs, shared sources, and changed Markdown:

   ```powershell
   pwsh -NoProfile -File .github\scripts\Test-OrganizationDefaults.ps1 -BaseRevision origin/main
   ```

## Verify

The result names the actual head and merge base, existing changed files,
Markdown files actually linted, checked deletions, and verified shared
configuration sources. Empty or unsupported-only diffs fail. Intentional
template deletion is checked as absence, not a missing-file error or a claim
that deleted content was linted. Regression tests are reported separately and
cannot disguise a scan that found no applicable input.

Every selected Markdown file is read literally and sent on stdin to
markdownlint-cli2 with the [unchanged shared rules][markdown].
An isolated temporary configuration sets `noInlineConfig: true`, so inline
disable/configuration directives cannot turn malformed Markdown into a pass.
Repository-local ignore/configuration files and glob-like filenames cannot
skip an input. Directive examples remain valid Markdown; they are not new rules.

The [shared PowerShell][powershell], [Markdown][markdown], and [zizmor][zizmor]
snapshots and [YAML baseline][yaml] are verified against the recorded immutable
Git blobs in `validation.psd1`. They are tooling sources, not copied PR-format
templates or producer-runtime dependencies. The [Pester runner][pester] comes
from the same immutable shared tooling revision.

The workflow uses `pull_request` activities `opened`, `synchronize`, `reopened`,
and `edited`, so retargeting a PR to `main` starts validation without a new head
commit. It checks out and verifies that actual head. Only `contents: read` is
granted; persisted credentials, per-language statuses, and PR-summary writes are
disabled. Other language checks use the pinned shared linter's exact
repository-relative filter. Control/backslash names, symbolic links, and
relevant inputs in its pruned directories fail explicitly.
Surviving PowerShell paths containing wildcard characters are also rejected:
the shared analyzer's path option could otherwise inspect a different file.

For deletion-only diffs there is no surviving content to lint. The report counts
the checked deletions and configuration sources, and the other-language lint
step does not run. This is not an empty input or a Markdown pass.

The exact hosted check is `Organization defaults validation`, produced by
GitHub Actions. A completed result at the actual PR head is required evidence;
local tests or a manually dispatched/skipped job cannot replace it.
Making that check required for `main` is a separately approved governance action,
not a rule or access change performed by this code.

## If it fails

| Symptom | Cause | Resolution |
| --- | --- | --- |
| No applicable changed input | Empty diff or unsupported-only files | Confirm the intended committed base/head; do not substitute regression-only evidence. |
| Markdown lint failure | Shared-rule violation, even if an inline directive disables it | Correct the content; do not suppress or skip validation. |
| Source mismatch | A shared configuration differs from its recorded source | Select and verify an immutable source refresh, then rerun the regressions. |
| Head/working-tree mismatch | Wrong checkout, incomplete history, or uncommitted content | Fetch the intended base/head and commit the intended changes. |
| Check does not hold merge | No required-check rule | Ask the governance owner to separately approve requiring the exact check/source. |

[pr-format]: https://msx.no/docs/Ways-of-Working/PR-Format/
[markdown]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/.markdown-lint.yml
[powershell]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/.powershell-psscriptanalyzer.psd1
[zizmor]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/zizmor.yaml
[yaml]: https://github.com/super-linter/super-linter/blob/4ce20838b8ab83717e78138c5b3a1407148e0918/TEMPLATES/.yaml-lint.yml
[pester]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/scripts/Invoke-PesterSuite.ps1
