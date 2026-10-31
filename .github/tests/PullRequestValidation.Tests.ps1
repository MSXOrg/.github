#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester setup and test blocks execute in separate scopes.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeDiscovery {
    $unsupportedNames = @(
        @{ Name = 'tab'; FileName = "changed`tfile.md"; Expected = '*control characters*' }
        @{ Name = 'form feed'; FileName = "changed$([char] 12)file.md"; Expected = '*control characters*' }
        @{ Name = 'DEL'; FileName = "changed$([char] 127)file.md"; Expected = '*control characters*' }
        @{ Name = 'backslash'; FileName = 'changed\file.md'; Expected = '*backslash*' }
    )
    $prunedDirectories = @('.pytest_cache', '.rbenv', '.terragrunt-cache', '.venv', '__pycache__', 'node_modules')
    $markdownCases = @(
        @{ Name = 'plain malformed heading'; Content = "# Broken!`n"; Passes = $false }
        @{ Name = 'whole-file disable'; Content = "<!-- markdownlint-disable -->`n# Broken!`n"; Passes = $false }
        @{ Name = 'rule-specific disable'; Content = "<!-- markdownlint-disable MD026 -->`n# Broken!`n"; Passes = $false }
        @{ Name = 'next-line disable'; Content = "<!-- markdownlint-disable-next-line MD026 -->`n# Broken!`n"; Passes = $false }
        @{ Name = 'inline configuration'; Content = "<!-- markdownlint-configure-file {`"MD026`": false} -->`n# Broken!`n"; Passes = $false }
        @{ Name = 'valid no-template Markdown'; Content = "# Valid`n"; Passes = $true }
        @{ Name = 'documented directive example'; Content = "# Example`n`n``````html`n<!-- markdownlint-disable -->`n```````n"; Passes = $true }
    )
}

BeforeAll {
    $sourceRoot = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..\..')).ProviderPath
    Import-Module -Name (Join-Path -Path $sourceRoot -ChildPath '.github\scripts\PullRequestValidation.psm1') -Force
    $markdownConfig = Join-Path -Path $sourceRoot -ChildPath '.github\linters\.markdown-lint.yml'
}

Describe 'Actual committed inputs without a PR template' {
    BeforeEach {
        $PSNativeCommandUseErrorActionPreference = $true
        $repository = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $repository
        git -C $repository init --quiet --initial-branch=main
        git -C $repository config user.name 'Validation fixture'
        git -C $repository config user.email 'fixture@example.invalid'
        git -C $repository config core.autocrlf false
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'base.md'), "# Base`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record anonymous no-template base'
        $base = git -C $repository rev-parse HEAD
    }

    It 'selects valid changed Markdown without requiring a template or copied scaffold' {
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'changed.md'), "# Changed`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Change Markdown without a template'
        $result = Get-ValidationInput -RepositoryPath $repository -BaseRevision $base
        $result.MarkdownFiles | Should -Contain 'changed.md'
        $result.DeletedFiles | Should -HaveCount 0
        Test-Path -LiteralPath (Join-Path -Path $repository -ChildPath '.github\pull_request_template.md') |
            Should -BeFalse
    }

    It 'retains intentional central-template removal as a checked deletion, not a missing-file failure' {
        $directory = Join-Path -Path $repository -ChildPath '.github'
        $null = New-Item -ItemType Directory -Path $directory
        $template = Join-Path -Path $directory -ChildPath 'pull_request_template.md'
        [IO.File]::WriteAllText($template, "# Legacy`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record anonymous legacy template'
        $base = git -C $repository rev-parse HEAD
        Remove-Item -LiteralPath $template
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Use canonical guidance without a template'
        $result = Get-ValidationInput -RepositoryPath $repository -BaseRevision $base
        $result.DeletedFiles | Should -Contain '.github/pull_request_template.md'
        $result.ExistingFiles | Should -HaveCount 0
        $result.MarkdownFiles | Should -HaveCount 0
    }

    It 'does not call an empty diff a complete validation pass' {
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*No applicable changed input*'
    }

    It 'does not count unrelated media as applicable Markdown' {
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'image.png'), 'anonymous')
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Add anonymous unsupported input'
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*No applicable changed input*'
    }

    It 'matches exact relative paths, including spaces and literal glob characters' {
        $path = Join-Path -Path $repository -ChildPath 'changed [one].md'
        [IO.File]::WriteAllText($path, "# Changed`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record literal Markdown filename'
        $result = Get-ValidationInput -RepositoryPath $repository -BaseRevision $base
        'changed [one].md' | Should -Match $result.LintFilter
        'docs/changed [one].md' | Should -Not -Match $result.LintFilter
        'changed o.md' | Should -Not -Match $result.LintFilter
    }

    It 'rejects wildcard-bearing PowerShell input instead of linting an unchanged matching file' {
        $unchanged = Join-Path -Path $repository -ChildPath 'changed o.ps1'
        [IO.File]::WriteAllText($unchanged, "Write-Output 'anonymous fixture'`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record unchanged ordinary PowerShell input'
        $base = git -C $repository rev-parse HEAD
        $changed = Join-Path -Path $repository -ChildPath 'changed [one].ps1'
        [IO.File]::WriteAllText($changed, "Invoke-Expression -Command `"'anonymous fixture'`"`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record a wildcard-bearing PowerShell filename'
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*PowerShell path contains wildcard characters*'
    }

    It 'rejects a <Name> filename before path or filter normalization' -ForEach $unsupportedNames {
        $blob = git -C $repository rev-parse HEAD:base.md
        # Index-only Unix paths avoid creating invalid Windows files.
        git -C $repository -c core.protectNTFS=false update-index --add --cacheinfo "100644,$blob,$FileName"
        git -C $repository commit --quiet -m 'Record nonportable filename'
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage $Expected
    }

    It 'rejects changed content in finder-pruned directory <_>' -ForEach $prunedDirectories {
        $directory = Join-Path -Path $repository -ChildPath $_
        $null = New-Item -ItemType Directory -Path $directory
        [IO.File]::WriteAllText((Join-Path -Path $directory -ChildPath 'broken.md'), "# Broken!`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record an excluded input'
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*linter discovery*'
    }

    It 'rejects committed symbolic links before reading their targets' {
        $path = Join-Path -Path $repository -ChildPath 'linked.md'
        [IO.File]::WriteAllText($path, "# Linked`n")
        $blob = git -C $repository hash-object -w $path
        git -C $repository config core.symlinks false
        git -C $repository update-index --add --cacheinfo "120000,$blob,linked.md"
        git -C $repository commit --quiet -m 'Record a symbolic-link input'
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*symbolic link*'
    }

    It 'rejects uncommitted content instead of certifying the reported HEAD' {
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'base.md'), "# Uncommitted`n")
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*working tree*'
    }

    It 'rejects staged changes instead of certifying an older HEAD' {
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'base.md'), "# Staged`n")
        git -C $repository add --all
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision $base } |
            Should -Throw -ExpectedMessage '*working tree*'
    }

    It 'fails explicitly when the intended base is unavailable' {
        { Get-ValidationInput -RepositoryPath $repository -BaseRevision 'missing-reference' } |
            Should -Throw -ExpectedMessage '*base revision*'
    }
}

Describe 'Changed Markdown uses the immutable shared rules without inline bypasses' {
    It 'checks <Name>' -ForEach $markdownCases {
        $path = Join-Path -Path $TestDrive -ChildPath 'anonymous.md'
        [IO.File]::WriteAllText($path, $Content)
        if ($Passes) {
            $result = Test-MarkdownFile -Path @($path) -ConfigurationPath $markdownConfig
            $result | Should -BeOfType ([pscustomobject])
            $result.CheckedFiles | Should -Be 1
        } else {
            { Test-MarkdownFile -Path @($path) -ConfigurationPath $markdownConfig } |
                Should -Throw -ExpectedMessage '*Markdown lint failed*'
        }
    }

    It 'does not count a zero-file Markdown scan as success' {
        { Test-MarkdownFile -Path @() -ConfigurationPath $markdownConfig } |
            Should -Throw -ExpectedMessage '*No Markdown input*'
    }

    It 'uses literal filenames rather than dropping glob-like input' {
        $path = Join-Path -Path $TestDrive -ChildPath 'changed [one].md'
        [IO.File]::WriteAllText($path, "# Broken!`n")
        { Test-MarkdownFile -Path @($path) -ConfigurationPath $markdownConfig } |
            Should -Throw -ExpectedMessage '*Markdown lint failed*'
    }
}

Describe 'Immutable validation configuration source' {
    It 'checks the shared configuration snapshots rather than a copied PR scaffold' {
        $result = Test-ValidationSource -RepositoryPath $sourceRoot
        $result.CheckedFiles | Should -Be 4
        $result.SourceCommit | Should -BeExactly '36da9154aa55d2052345fb2f28b812b29daf8bc9'
    }

    It 'rejects a source entry that escapes the checkout' {
        $repository = Join-Path -Path $TestDrive -ChildPath 'source-containment'
        $directory = Join-Path -Path $repository -ChildPath '.github'
        $null = New-Item -ItemType Directory -Path $directory -Force
        [IO.File]::WriteAllText(
            (Join-Path -Path $directory -ChildPath 'validation.psd1'),
            "@{ ConfigFiles = @{ '../outside.yml' = 'not-a-source-blob' } }"
        )
        { Test-ValidationSource -RepositoryPath $repository } |
            Should -Throw -ExpectedMessage '*escapes the source checkout*'
    }

    It 'rejects a zero-configuration source scan' {
        $repository = Join-Path -Path $TestDrive -ChildPath 'empty-source'
        $directory = Join-Path -Path $repository -ChildPath '.github'
        $null = New-Item -ItemType Directory -Path $directory -Force
        [IO.File]::WriteAllText(
            (Join-Path -Path $directory -ChildPath 'validation.psd1'),
            '@{ ConfigFiles = @{} }'
        )
        { Test-ValidationSource -RepositoryPath $repository } |
            Should -Throw -ExpectedMessage '*source correspondence checked nothing*'
    }
}

Describe 'Source controller accepts canonical-guidance-only inputs' {
    BeforeEach {
        $PSNativeCommandUseErrorActionPreference = $false
        $repository = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $repository
        $paths = @(
            '.github\scripts\PullRequestValidation.psm1'
            '.github\scripts\Test-OrganizationDefaults.ps1'
            '.github\validation.psd1'
            '.github\linters\.markdown-lint.yml'
            '.github\linters\.powershell-psscriptanalyzer.psd1'
            '.github\linters\.yaml-lint.yml'
            '.github\linters\zizmor.yml'
        )
        foreach ($path in $paths) {
            $destination = Join-Path -Path $repository -ChildPath $path
            $null = New-Item -ItemType Directory -Path (Split-Path -Path $destination -Parent) -Force
            Copy-Item -LiteralPath (Join-Path -Path $sourceRoot -ChildPath $path) -Destination $destination
        }
        git -C $repository init --quiet --initial-branch=main
        git -C $repository config user.name 'Validation fixture'
        git -C $repository config user.email 'fixture@example.invalid'
        git -C $repository config core.autocrlf false
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record anonymous source tooling without templates'
        $base = git -C $repository rev-parse HEAD
        $controller = Join-Path -Path $repository -ChildPath '.github\scripts\Test-OrganizationDefaults.ps1'
    }

    It 'validates no-template source Markdown without looking for a fixture scaffold' {
        [IO.File]::WriteAllText((Join-Path -Path $repository -ChildPath 'changed.md'), "# Valid`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Change source Markdown without template files'
        pwsh -NoProfile -File $controller -BaseRevision $base
        $LASTEXITCODE | Should -Be 0
    }

    It 'checks intentional removal without pretending zero Markdown files were linted' {
        $template = Join-Path -Path $repository -ChildPath '.github\pull_request_template.md'
        [IO.File]::WriteAllText($template, "# Legacy`n")
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Record anonymous legacy distribution path'
        $base = git -C $repository rev-parse HEAD
        Remove-Item -LiteralPath $template
        git -C $repository add --all
        git -C $repository commit --quiet -m 'Remove central template distribution'
        pwsh -NoProfile -File $controller -BaseRevision $base
        $LASTEXITCODE | Should -Be 0
    }
}
