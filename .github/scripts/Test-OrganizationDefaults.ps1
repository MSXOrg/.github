#Requires -Version 7.4

<#
    .SYNOPSIS
    Validate actual changed inputs and the complete organization fallback.

    .DESCRIPTION
    Check the actual head and changed templates, verify the isolated source fixture,
    and report changed Markdown separately from unchanged fallback content.
    Pass an exact changed-file filter to the shared linter without write permissions.

    .EXAMPLE
    ./Test-OrganizationDefaults.ps1 -BaseRevision 'origin/main'
    Validate committed changes against their merge base with origin/main.

    .INPUTS
    None

    You can't pipe objects to Test-OrganizationDefaults.ps1.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    The actual head and counts of changed inputs and checked templates.
#>
[OutputType([pscustomobject])]
[CmdletBinding()]
param(
    # Base commit or reference; local use compares committed changes only.
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $BaseRevision = 'origin/main',

    # Expected pull request head supplied by the hosted event.
    [Parameter()]
    [ValidatePattern('^$|^[0-9a-fA-F]{40}$')]
    [string] $ExpectedHead = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repository = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..')).ProviderPath
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'PullRequestValidation.psm1') -Force
$inputs = Get-ValidationInput -RepositoryPath $repository -BaseRevision $BaseRevision
if ($ExpectedHead -and $inputs.HeadCommit -cne $ExpectedHead) {
    throw 'The checked-out commit differs from the actual pull request head; this result cannot certify that head.'
}

Write-Information -MessageData "Actual head: $($inputs.HeadCommit); merge base: $($inputs.MergeBase)" -InformationAction Continue
foreach ($path in $inputs.ChangedFiles) {
    Write-Information -MessageData "Applicable changed input: $path" -InformationAction Continue
}
foreach ($path in $inputs.MarkdownFiles) {
    $content = [IO.File]::ReadAllText((Join-Path -Path $repository -ChildPath $path))
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Changed Markdown '$path' is empty; no Markdown content was validated."
    }
}

$fixturePath = Join-Path -Path $PSScriptRoot -ChildPath '..\tests\fixtures\pull_request_template.md'
$fixture = Test-PullRequestTemplate -Content ([IO.File]::ReadAllText($fixturePath))
$productionTemplates = @($inputs.TemplateFiles | Where-Object { $_ -ne '.github/tests/fixtures/pull_request_template.md' })
foreach ($path in $inputs.TemplateFiles) {
    $templatePath = Join-Path -Path $repository -ChildPath $path
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        throw "Changed fallback '$path' is missing. Restore its complete source-aligned scaffold."
    }
    $null = Test-PullRequestTemplate -Content ([IO.File]::ReadAllText($templatePath))
    Write-Information -MessageData "Source-aligned changed template: $path" -InformationAction Continue
}
if ($productionTemplates.Count -eq 0) {
    Write-Information -MessageData 'No production fallback changed: unchanged legacy content is not certified as the candidate.' -InformationAction Continue
}
if ($inputs.MarkdownFiles.Count -eq 0) {
    Write-Information -MessageData 'No changed Markdown: only the applicable changed code/configuration is sent to its linters.' -InformationAction Continue
}

$filter = $inputs.LintFilter
if ($env:GITHUB_OUTPUT) {
    [IO.File]::AppendAllText($env:GITHUB_OUTPUT, "files_regex=$filter`n")
}
$report = [pscustomobject]@{
    HeadCommit = $inputs.HeadCommit
    ChangedInputs = $inputs.ExistingFiles.Count
    ChangedMarkdown = $inputs.MarkdownFiles.Count
    ChangedProductionTemplates = $productionTemplates.Count
    SourceFixtureTemplates = 1
    SourceCommit = $fixture.SourceCommit
}
if ($env:GITHUB_STEP_SUMMARY) {
    $summary = @(
        '## Organization-default validation inputs'
        ''
        "| Actual head | ``$($report.HeadCommit)`` |"
        '| --- | --- |'
        "| Applicable changed files sent to linters | $($report.ChangedInputs) |"
        "| Changed Markdown | $($report.ChangedMarkdown) |"
        "| Changed production templates structurally checked | $($report.ChangedProductionTemplates) |"
        '| Isolated source fixtures checked (not unchanged fallback evidence) | 1 |'
        "| Immutable fixture source | ``$($report.SourceCommit)`` |"
        ''
        'Fixture checks do not certify unchanged legacy templates. Lint and Pester results follow separately.'
    )
    [IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($summary -join "`n") + "`n")
}
$report
