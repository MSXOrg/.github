---
title: Validate organization-default pull requests
description: Check changed files and source-bound fallback scaffolds locally.
---

# Validate organization-default pull requests

Run the same fixture and changed-input checks used by the read-only
`Organization defaults validation` job.

## Before starting

- Use PowerShell 7.4 or later, Git, and Node.js/npm.
- For local code/configuration lint, also provide PSScriptAnalyzer, yamllint,
  actionlint, and zizmor.
- Fetch the intended base and commit the changes being checked. The diff command
  examines commits, not staged or untracked files.
- Allow dependency restoration when needed: the source-native runner pins
  Pester 6.1.0 and verifies its module GUID. Markdown examples pin
  markdownlint-cli2 0.24.0.

## Steps

1. Fetch the base: `git fetch origin main`.
2. Run the valid, malformed, and changed-input fixture suite:

   ```powershell
   pwsh -NoProfile -File .github\scripts\Invoke-PesterSuite.ps1 -Path .github\tests -RequiredVersion 6.1.0
   ```

3. Validate the committed inputs and any changed complete fallback:

   ```powershell
   pwsh -NoProfile -File .github\scripts\Test-OrganizationDefaults.ps1 -BaseRevision origin/main
   ```

4. Lint the actual changed Markdown with the shared configuration:

   ```powershell
   $ErrorActionPreference = 'Stop'
   Import-Module -Name (Resolve-Path -LiteralPath '.github\scripts\PullRequestValidation.psm1').ProviderPath -Force
   $inputs = Get-ValidationInput -RepositoryPath $PWD.ProviderPath -BaseRevision 'origin/main'
   if ($inputs.MarkdownFiles.Count -eq 0) {
       throw 'No changed Markdown: this command cannot report a Markdown pass.'
   }
   $npx = 'npx'
   if ($IsWindows) {
       $npx = 'npx.cmd'
   }
   $files = @($inputs.MarkdownFiles | ForEach-Object { ':' + $_ })
   & $npx --yes -- markdownlint-cli2@0.24.0 --config '.github\linters\.markdown-lint.yml' @files
   if ($LASTEXITCODE -ne 0) {
       throw 'Changed Markdown lint failed.'
   }
   ```

## Verify

The fixture suite must discover tests, reject malformed scaffolds, and pass its
valid cases. The changed-input report identifies the actual head and counts
changed Markdown and production templates separately from its isolated fixture.
Empty/unsupported-only diffs fail explicitly. Unchanged fallback content is not
certified as the candidate. A changed missing or source-divergent fallback fails.

The hosted job checks out the pull request head, compares its merge base, and
passes an exact changed-file filter to the shared linter. Only Markdown,
PowerShell, YAML, and workflow correctness/security checks are enabled. There
is no path trigger filter, write token, publication, or label mutation.
Per-language status writes and Super-Linter's pull request summary comments are
explicitly disabled; the job itself supplies the named check. Rename detection
is disabled in the input scan so removing a fallback cannot hide its old path.

The complete fixture and its LF-normalized SHA-256 in `validation.psd1` correspond
to the [immutable complete scaffold][scaffold], including all five classifier
groups, scoped supporting pairs, adoption/plan/convergence prompts, and conditional
final decision fields. This source snapshot is not a shipped producer runtime or
an installation dependency. The check validates template code, not filled-in PR
descriptions or a producer's effective release decision.

The [shared Markdown configuration][markdown], [PowerShell configuration][powershell],
and [Pester runner][pester] are vendored from an immutable default-branch revision,
as is the [shared zizmor configuration][zizmor].
The YAML configuration matches the [pinned shared linter baseline][yaml].
Refresh a snapshot only against a selected immutable source, compare the complete
source content independently, and rerun the valid/malformed suite.

For local code/configuration checks, use `Invoke-ScriptAnalyzer` with
`.github\linters\.powershell-psscriptanalyzer.psd1`,
`yamllint -c .github\linters\.yaml-lint.yml`, `actionlint`, and
`zizmor --offline -c .github\linters\zizmor.yml`.
Hosted checks use the pinned Super-Linter integration;
local fixture results do not replace a completed result at the actual PR head.

GitHub-native Dependabot uses its [default three-day cooldown][cooldown].
The shared zizmor configuration disables only the outdated missing-cooldown
audit; all other workflow audits remain enabled. No cooldown override or
label configuration is introduced.

## If it fails

| Symptom | Cause | Resolution |
| --- | --- | --- |
| No applicable changed input | Empty diff or unsupported-only files | Confirm the intended committed base/head; do not count fixture-only evidence as a changed-input pass. |
| Scaffold/source mismatch | Changed marker, groups, prompts, or decision structure | Restore the complete selected source scaffold and retain only comment-based authoring guidance before it. |
| Head mismatch or missing merge base | Wrong checkout or incomplete history | Fetch the intended base/head and rerun at the actual PR head. |
| Passing check does not hold merge | No required-check rule | Have the governance owner separately approve requiring `Organization defaults validation` from GitHub Actions for `main`. This code does not modify rulesets or access. |

[scaffold]: https://github.com/MSXOrg/docs/blob/1ececb2bd9f1680c87cec15a45ac927a554fce9c/src/docs/Ways-of-Working/PR-Format.md#copy-the-complete-template
[markdown]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/.markdown-lint.yml
[powershell]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/.powershell-psscriptanalyzer.psd1
[pester]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/scripts/Invoke-PesterSuite.ps1
[yaml]: https://github.com/super-linter/super-linter/blob/4ce20838b8ab83717e78138c5b3a1407148e0918/TEMPLATES/.yaml-lint.yml
[zizmor]: https://github.com/MSXOrg/docs/blob/36da9154aa55d2052345fb2f28b812b29daf8bc9/.github/linters/zizmor.yaml
[cooldown]: https://github.blog/changelog/2026-07-14-dependabot-version-updates-introduce-default-package-cooldown/
