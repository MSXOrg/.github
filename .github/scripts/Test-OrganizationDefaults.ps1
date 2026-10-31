#Requires -Version 7.4

<#
    .SYNOPSIS
    Validate the source repository's actual changed inputs.

    .DESCRIPTION
    Check the actual head and shared configuration sources without requiring a
    PR template. Lint changed Markdown and report intentional deletions separately.
    Pass an exact changed-file filter to the shared linter without write permissions.

    .EXAMPLE
    ./Test-OrganizationDefaults.ps1 -BaseRevision 'origin/main'
    Validate committed changes against their merge base with origin/main.

    .INPUTS
    None

    You can't pipe objects to Test-OrganizationDefaults.ps1.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    The actual head and counts of checked content, deletions, and configuration sources.
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
$source = Test-ValidationSource -RepositoryPath $repository
$checkedMarkdown = 0
if ($inputs.MarkdownFiles.Count -eq 0) {
    Write-Information -MessageData 'No existing changed Markdown: deletions are checked as absent, not counted as linted content.' -InformationAction Continue
} else {
    $markdownPaths = @($inputs.MarkdownFiles | ForEach-Object { Join-Path -Path $repository -ChildPath $_ })
    $markdown = Test-MarkdownFile -Path $markdownPaths -ConfigurationPath (
        Join-Path -Path $repository -ChildPath '.github\linters\.markdown-lint.yml'
    )
    $checkedMarkdown = $markdown.CheckedFiles
}
foreach ($path in $inputs.DeletedFiles) {
    Write-Information -MessageData "Checked deletion: $path" -InformationAction Continue
}

$filter = $inputs.LintFilter
if ($env:GITHUB_OUTPUT) {
    [IO.File]::AppendAllText($env:GITHUB_OUTPUT, "files_regex=$filter`nexisting_files=$($inputs.ExistingFiles.Count)`n")
}
$report = [pscustomobject]@{
    HeadCommit = $inputs.HeadCommit
    ChangedInputs = $inputs.ExistingFiles.Count
    CheckedMarkdown = $checkedMarkdown
    CheckedDeletions = $inputs.DeletedFiles.Count
    ConfigurationSources = $source.CheckedFiles
    SourceCommit = $source.SourceCommit
}
if ($env:GITHUB_STEP_SUMMARY) {
    $summary = @(
        '## Organization-default validation inputs'
        ''
        "| Actual head | ``$($report.HeadCommit)`` |"
        '| --- | --- |'
        "| Applicable changed files sent to linters | $($report.ChangedInputs) |"
        "| Changed Markdown actually linted | $($report.CheckedMarkdown) |"
        "| Checked deletions, not counted as linted content | $($report.CheckedDeletions) |"
        "| Shared configuration sources verified | $($report.ConfigurationSources) |"
        "| Immutable configuration source | ``$($report.SourceCommit)`` |"
        ''
        'PR templates are not required or copied. Regression tests and other language lint follow separately.'
    )
    [IO.File]::AppendAllText($env:GITHUB_STEP_SUMMARY, ($summary -join "`n") + "`n")
}
$report
