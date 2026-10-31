#Requires -Version 7.4

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-ValidationSource {
    <#
        .SYNOPSIS
        Verify the shared validation configuration snapshots.

        .DESCRIPTION
        Compare Git-normalized configuration blobs with their recorded immutable
        sources. This verifies tooling configuration, not a copied PR template.

        .EXAMPLE
        Test-ValidationSource -RepositoryPath $repository
        Return the number of verified configurations and the source revision.

        .INPUTS
        None

        You can't pipe objects to Test-ValidationSource.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The verified configuration count and immutable source revision.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # Root of the clean source checkout being validated.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RepositoryPath
    )

    $PSNativeCommandUseErrorActionPreference = $false
    $repository = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
    $source = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $repository -ChildPath '.github\validation.psd1')
    if ($source.ConfigFiles.Count -eq 0) {
        throw 'No shared validation configuration was recorded; source correspondence checked nothing.'
    }
    foreach ($entry in $source.ConfigFiles.GetEnumerator()) {
        $path = [IO.Path]::GetFullPath((Join-Path -Path $repository -ChildPath $entry.Key))
        $relative = [IO.Path]::GetRelativePath($repository, $path)
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\.\.(?:[\\/]|$)') {
            throw 'A validation configuration path escapes the source checkout.'
        }
        $blob = git -C $repository hash-object "--path=$($entry.Key)" -- $path
        if ($LASTEXITCODE -ne 0 -or $blob -cne $entry.Value) {
            throw "Shared validation configuration '$($entry.Key)' differs from its recorded immutable source."
        }
    }

    [pscustomobject]@{
        CheckedFiles = $source.ConfigFiles.Count
        SourceCommit = $source.SourceCommit
    }
}

function Test-MarkdownFile {
    <#
        .SYNOPSIS
        Lint every supplied Markdown file with the shared rules.

        .DESCRIPTION
        Send literal file contents to the existing Markdown tool on stdin from an
        isolated configuration directory. Inline overrides and repository-local
        ignore/configuration files cannot hide violations or skip selected files.

        .EXAMPLE
        Test-MarkdownFile -Path $files -ConfigurationPath $configuration
        Return the checked file count or throw with the failing file's diagnostic.

        .INPUTS
        None

        You can't pipe objects to Test-MarkdownFile.

        .OUTPUTS
        System.Management.Automation.PSCustomObject

        The number of files actually linted and the pinned tool version.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        # Literal files selected from the validated committed diff.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]] $Path,

        # Absolute shared Markdown rule configuration.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationPath
    )

    if ($Path.Count -eq 0) {
        throw 'No Markdown input was supplied; a zero-file lint is not a pass.'
    }
    $files = @($Path | ForEach-Object { (Resolve-Path -LiteralPath $_).ProviderPath })
    $configuration = (Resolve-Path -LiteralPath $ConfigurationPath).ProviderPath
    $source = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\validation.psd1')
    if ($source.MarkdownlintVersion -notmatch '^\d+\.\d+\.\d+$') {
        throw 'The Markdown tool version is missing or invalid.'
    }
    $npx = 'npx'
    if ($IsWindows) {
        $npx = 'npx.cmd'
    }
    $temporaryDirectory = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().ToString())
    $null = New-Item -ItemType Directory -Path $temporaryDirectory
    $temporaryConfiguration = Join-Path -Path $temporaryDirectory -ChildPath 'validation.markdownlint-cli2.jsonc'
    $options = @{
        config = @{ extends = $configuration }
        noInlineConfig = $true
    } | ConvertTo-Json -Depth 3
    [IO.File]::WriteAllText($temporaryConfiguration, $options)

    Push-Location -LiteralPath $temporaryDirectory
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        foreach ($file in $files) {
            $content = [IO.File]::ReadAllText($file)
            if ([string]::IsNullOrWhiteSpace($content)) {
                throw "Markdown lint failed for '$file': the file is empty."
            }
            Write-Information -MessageData "Checking Markdown: $file" -InformationAction Continue
            $diagnostics = @(
                $content | & $npx --yes -- "markdownlint-cli2@$($source.MarkdownlintVersion)" --config $temporaryConfiguration -
            )
            foreach ($diagnostic in $diagnostics) {
                Write-Information -MessageData $diagnostic -InformationAction Continue
            }
            if ($LASTEXITCODE -ne 0) {
                throw "Markdown lint failed for '$file' (exit $LASTEXITCODE)."
            }
        }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $temporaryConfiguration
        Remove-Item -LiteralPath $temporaryDirectory
    }
    [pscustomobject]@{
        CheckedFiles = $files.Count
        ToolVersion = $source.MarkdownlintVersion
    }
}

function Get-ValidationInput {
    <#
        .SYNOPSIS
        Identify the actual committed inputs changed by a pull request.

        .DESCRIPTION
        Compare the merge base with HEAD, report intentional deletions separately,
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

        Commit identities and existing, deleted, and Markdown input paths.
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
    # Retain both paths so a rename cannot hide a checked deletion.
    $changed = git -C $repository diff --no-renames --name-only --diff-filter=ACDMRT -z $mergeBase $headCommit --
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot enumerate the actual changed inputs.'
    }
    $paths = @(($changed -join "`n") -split "`0" | Where-Object { $_ })
    if (@($paths | Where-Object { $_ -match '[\x00-\x1f\x7f]' }).Count -gt 0) {
        throw 'Changed filenames containing control characters are unsupported; rename those files before validation.'
    }
    if (@($paths | Where-Object { $_.Contains('\') }).Count -gt 0) {
        throw 'Changed Git paths containing a literal backslash are unsupported; rename those files before validation.'
    }
    $relevant = @($paths | Where-Object { $_ -match '\.(md|ps1|psm1|psd1|yml|yaml)$' })
    # These directories are pruned by the pinned shared linter finder.
    $prunedPath = '(^|/)(\.git|\.pytest_cache|\.rbenv|\.terragrunt-cache|\.venv|__pycache__|node_modules)/'
    if (@($relevant | Where-Object { $_ -cmatch $prunedPath }).Count -gt 0) {
        throw 'An applicable changed input is excluded by shared linter discovery; move it to a linted path before validation.'
    }
    if ($relevant.Count -gt 0) {
        $literalPaths = @($relevant | ForEach-Object { ':(literal)' + $_ })
        $modes = git -C $repository ls-tree -r -z --format='%(objectmode)' $headCommit -- @literalPaths
        if ($LASTEXITCODE -ne 0) {
            throw 'Cannot inspect committed validation input file types.'
        }
        if ((($modes -join "`n") -split "`0") -contains '120000') {
            throw 'A committed validation input is a symbolic link; replace it with a regular file before validation.'
        }
    }
    $status = git -C $repository status --porcelain=v1 --untracked-files=all -z
    if ($LASTEXITCODE -ne 0) {
        throw 'Cannot verify the validation working tree.'
    }
    if (-not [string]::IsNullOrEmpty(($status -join "`n"))) {
        throw 'The working tree differs from HEAD. Commit the intended changes before certifying that head.'
    }
    $existing = @($relevant | Where-Object {
            Test-Path -LiteralPath (Join-Path -Path $repository -ChildPath $_) -PathType Leaf
        })
    $deleted = @($relevant | Where-Object { $_ -notin $existing })
    if ($relevant.Count -eq 0) {
        throw 'No applicable changed input was found. Fixture self-tests are not a complete pull request validation pass.'
    }

    $escapedPaths = @($existing | ForEach-Object { [regex]::Escape($_) })
    $filter = '^(' + ($escapedPaths -join '|') + ')$'

    [pscustomobject]@{
        HeadCommit = $headCommit
        MergeBase = $mergeBase
        ChangedFiles = $relevant
        ExistingFiles = $existing
        MarkdownFiles = @($existing | Where-Object { $_ -match '\.md$' })
        DeletedFiles = $deleted
        LintFilter = $filter
    }
}

Export-ModuleMember -Function Test-ValidationSource, Test-MarkdownFile, Get-ValidationInput
