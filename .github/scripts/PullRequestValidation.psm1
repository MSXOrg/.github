#Requires -Version 7.4

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-PullRequestTemplate {
    <#
        .SYNOPSIS
        Validate a complete organization fallback against its immutable source.

        .DESCRIPTION
        Check the announcement boundary, classifier order, scoped supporting pairs,
        final conditional decision fields, and complete source correspondence.
        Only HTML authoring comments may precede the recorded scaffold.

        .EXAMPLE
        Test-PullRequestTemplate -Content $template
        Return structural counts and the verified source revision.

        .INPUTS
        None

        You can't pipe objects to Test-PullRequestTemplate.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The verified source revision, digest, and structural counts.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # Complete template text, not a filled-in pull request description.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $content = ($Content -replace '\r\n?', "`n").TrimStart([char] 0xfeff)
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw 'The fallback template is empty.'
    }

    $marker = '<!-- ANNOUNCEMENT STOP -->'
    if ([regex]::Matches($content, [regex]::Escape($marker)).Count -ne 1 -or
        [regex]::Matches($content, '(?m)^<!-- ANNOUNCEMENT STOP -->$').Count -ne 1) {
        throw 'The fallback must contain exactly one standalone announcement marker.'
    }

    $starts = [regex]::Matches($content, '(?m)^\{\{ One or two short summary paragraphs')
    if ($starts.Count -ne 1) {
        throw 'The complete scaffold is missing or ambiguous; restore the pinned source.'
    }
    $prefix = $content.Substring(0, $starts[0].Index) -replace '(?s)<!--.*?-->', ''
    if (-not [string]::IsNullOrWhiteSpace($prefix)) {
        throw 'The scaffold prefix may contain only complete HTML authoring comments.'
    }
    $body = $content.Substring($starts[0].Index).TrimEnd() + "`n"

    $classifiers = [regex]::Matches($body, '(?m)^## (?<name>Breaking|Removed|New|Changed|Fixed):')
    $names = @($classifiers | ForEach-Object { $_.Groups['name'].Value })
    if (($names -join ',') -cne 'Breaking,Removed,New,Changed,Fixed') {
        throw 'The complete scaffold requires five ordered classifier groups: Breaking, Removed, New, Changed, Fixed.'
    }

    $release = [regex]::Matches($body, '(?s)<details>\n<summary>Release decisions</summary>.*?</details>')
    if ($release.Count -ne 1 -or $release[0].Index -lt $classifiers[4].Index -or
        $body.Substring($release[0].Index).TrimEnd() -cne $release[0].Value) {
        throw 'The complete scaffold requires one final release-decision block after all result groups.'
    }

    $sections = [regex]::Matches(
        $body,
        '(?ms)^## (?:Breaking|Removed|New|Changed|Fixed):.*?(?=^## |<details>\n<summary>Release decisions</summary>|\z)'
    )
    foreach ($section in $sections) {
        $technical = [regex]::Matches($section.Value, '(?s)<details>\n<summary>Technical details</summary>.*?</details>')
        $references = [regex]::Matches($section.Value, '(?s)<details>\n<summary>Related references</summary>.*?</details>')
        if ($technical.Count -ne 1 -or $references.Count -ne 1 -or
            $technical[0].Index -gt $references[0].Index -or
            [regex]::Matches($section.Value, '<details>').Count -ne 2) {
            throw 'Every classifier requires one scoped Technical details block followed by one scoped Related references block.'
        }
    }

    $fields = [regex]::Matches($release[0].Value, '(?m)^- \*\*(?<name>Release|Version bump|Mode|Labels):\*\*')
    $fieldNames = @($fields | ForEach-Object { $_.Groups['name'].Value })
    if (($fieldNames -join ',') -cne 'Release,Version bump,Mode,Labels') {
        throw 'The final release-decision fields must be Release, Version bump, Mode, and Labels, in order.'
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath '..\validation.psd1'
    $source = Import-PowerShellDataFile -LiteralPath $sourcePath
    $digest = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($body))
    ).ToLowerInvariant()
    if ($digest -cne $source.TemplateSha256) {
        throw "The complete scaffold differs from the pinned source $($source.SourceRepository)@$($source.SourceCommit)."
    }

    [pscustomobject]@{
        SourceCommit = $source.SourceCommit
        TemplateSha256 = $digest
        AnnouncementMarkers = 1
        Classifiers = $classifiers.Count
        ScopedDetails = $sections.Count
        ReleaseDecisionBlocks = $release.Count
    }
}

function Get-ValidationInput {
    <#
        .SYNOPSIS
        Identify the actual committed inputs changed by a pull request.

        .DESCRIPTION
        Compare the merge base with HEAD, retain deleted templates for explicit failure,
        and distinguish changed Markdown from unchanged files and fixture self-tests.
        An empty or unsupported-only change cannot become a validation pass.

        .EXAMPLE
        Get-ValidationInput -RepositoryPath $repository -BaseRevision 'origin/main'
        Return actual head, merge base, and applicable changed paths.

        .INPUTS
        None

        You can't pipe objects to Get-ValidationInput.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        Commit identities and changed input, Markdown, and template paths.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # Absolute root of the target checkout.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RepositoryPath,

        # Base commit or reference used to find the pull request's merge base.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BaseRevision
    )

    $PSNativeCommandUseErrorActionPreference = $false
    $repository = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
    $baseCommit = git -C $repository rev-parse --verify --end-of-options "$BaseRevision^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot resolve the base revision '$BaseRevision'. Fetch the intended base before validation."
    }
    $headCommit = git -C $repository rev-parse --verify HEAD
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot resolve the actual pull request head.'
    }
    $mergeBase = git -C $repository merge-base $baseCommit $headCommit
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot find the merge base. Fetch the complete base and head history.'
    }
    # Retain the old path when a rename removes a GitHub template lookup file.
    $changed = git -C $repository diff --no-renames --name-only --diff-filter=ACDMRT -z $mergeBase $headCommit --
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot enumerate the actual changed inputs.'
    }
    $paths = @(($changed -join "`n") -split "`0" | Where-Object { $_ })
    if (@($paths | Where-Object { $_ -match '[\r\n]' }).Count -gt 0) {
        throw 'Changed filenames containing line breaks are unsupported; rename those files before validation.'
    }
    $relevant = @($paths | Where-Object { $_ -match '\.(md|ps1|psm1|psd1|yml|yaml)$' })
    $templates = @($relevant | Where-Object {
            $_ -match '^\.github/(pull_request_template\.md|PULL_REQUEST_TEMPLATE/[^/]+\.md)$' -or
            $_ -eq '.github/tests/fixtures/pull_request_template.md'
        })
    $existing = @($relevant | Where-Object {
            Test-Path -LiteralPath (Join-Path -Path $repository -ChildPath $_) -PathType Leaf
        })
    if ($existing.Count -eq 0 -and $templates.Count -eq 0) {
        throw 'No applicable changed input was found. Fixture self-tests are not a complete pull request validation pass.'
    }

    [pscustomobject]@{
        HeadCommit = $headCommit
        MergeBase = $mergeBase
        ChangedFiles = $relevant
        ExistingFiles = $existing
        MarkdownFiles = @($existing | Where-Object { $_ -match '\.md$' })
        TemplateFiles = $templates
    }
}

Export-ModuleMember -Function Test-PullRequestTemplate, Get-ValidationInput
