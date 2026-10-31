#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester discovers and executes setup and test blocks in separate scopes.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeDiscovery {
    $fixturePath = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures\pull_request_template.md'
    $fixture = [IO.File]::ReadAllText($fixturePath) -replace '\r\n?', "`n"
    $marker = '<!-- ANNOUNCEMENT STOP -->'
    $technical = [regex]::Match($fixture, '(?s)<details>\n<summary>Technical details</summary>.*?</details>').Value
    $references = [regex]::Match($fixture, '(?s)<details>\n<summary>Related references</summary>.*?</details>').Value
    $release = [regex]::Match($fixture, '(?s)<details>\n<summary>Release decisions</summary>.*?</details>').Value
    $malformed = @(
        @{ Name = 'missing announcement marker'; Content = $fixture.Replace($marker, ''); ExpectedError = '*announcement marker*' }
        @{ Name = 'duplicate announcement marker'; Content = $fixture.Replace($marker, "$marker`n$marker"); ExpectedError = '*announcement marker*' }
        @{ Name = 'fenced announcement marker'; Content = $fixture.Replace($marker, "``````markdown`n$marker`n``````"); ExpectedError = '*pinned source*' }
        @{ Name = 'marker after a result'; Content = $fixture.Replace("$marker`n", '').Replace('## Removed:', "$marker`n## Removed:"); ExpectedError = '*pinned source*' }
        @{ Name = 'missing classifier'; Content = $fixture.Replace('## Removed:', '## Other:'); ExpectedError = '*classifier*' }
        @{ Name = 'unordered classifiers'; Content = $fixture.Replace('## Breaking:', '## Swap:').Replace('## New:', '## Breaking:').Replace('## Swap:', '## New:'); ExpectedError = '*classifier*' }
        @{ Name = 'missing scoped evidence'; Content = $fixture.Replace($technical, ''); ExpectedError = '*scoped*' }
        @{ Name = 'missing scoped references'; Content = $fixture.Replace($references, ''); ExpectedError = '*scoped*' }
        @{ Name = 'references before evidence'; Content = $fixture.Replace("$technical`n`n$references", "$references`n`n$technical"); ExpectedError = '*scoped*' }
        @{ Name = 'global evidence'; Content = $technical + "`n" + $fixture.Replace($technical, ''); ExpectedError = '*prefix*' }
        @{ Name = 'missing final decision'; Content = $fixture.Replace($release, ''); ExpectedError = '*final release-decision*' }
        @{ Name = 'decision before results'; Content = $fixture.Replace($release, '').Replace($marker, "$marker`n$release"); ExpectedError = '*final release-decision*' }
        @{ Name = 'duplicate decision'; Content = $fixture + $release; ExpectedError = '*final release-decision*' }
        @{ Name = 'missing resolved bump'; Content = $fixture.Replace('- **Version bump:**', '- **Other:**'); ExpectedError = '*release-decision fields*' }
        @{ Name = 'missing conditional no-release guidance'; Content = $fixture.Replace("Delete this field when Release`n  is No.", ''); ExpectedError = '*pinned source*' }
        @{ Name = 'missing adoption instructions'; Content = $fixture.Replace('adoption actions or an explicit no-action result.', 'See the diff for instructions.'); ExpectedError = '*pinned source*' }
        @{ Name = 'unresolved source drift'; Content = $fixture.Replace('documented shared default', 'patch-only AutoPatching'); ExpectedError = '*pinned source*' }
        @{ Name = 'non-comment prefix'; Content = "# Unrelated heading`n$fixture"; ExpectedError = '*prefix*' }
    )
    $unsupportedFilenames = @(
        @{ CaseName = 'a tab'; FileName = "changed`tfile.md" }
        @{ CaseName = 'a form feed'; FileName = "changed$([char] 12)file.md" }
        @{ CaseName = 'a delete control character'; FileName = "changed$([char] 127)file.md" }
    )
    $lookupLocations = @(
        @{ Location = 'pull_request_template.md' }
        @{ Location = 'docs/pull_request_template.md' }
        @{ Location = 'PULL_REQUEST_TEMPLATE/default.md' }
        @{ Location = 'docs/PULL_REQUEST_TEMPLATE/default.md' }
    )
    $dirtyInputs = @(
        @{ Location = 'changed.md' }
        @{ Location = '.github/pull_request_template.md' }
        @{ Location = '.github/tests/fixtures/pull_request_template.md' }
        @{ Location = '.github/validation.psd1' }
    )
}

BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\scripts\PullRequestValidation.psm1'
    Import-Module -Name $modulePath -Force
    $fixturePath = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures\pull_request_template.md'
    $valid = [IO.File]::ReadAllText($fixturePath) -replace '\r\n?', "`n"
}

Describe 'Pinned complete fallback scaffold' {
    It 'accepts the independently recorded source fixture' {
        $result = Test-PullRequestTemplate -Content $valid
        $result.TemplateSha256 | Should -BeExactly '94fd209828f902b5faf4af9248826078843ea1ce37f168049606b53cfb6802c4'
        $result.AnnouncementMarkers | Should -Be 1
        $result.Classifiers | Should -Be 5
        $result.ScopedDetails | Should -Be 5
        $result.ReleaseDecisionBlocks | Should -Be 1
    }

    It 'accepts a comment-only authoring wrapper and CRLF line endings' {
        $content = "<!-- Authoring guidance only. -->`n" + $valid
        $result = Test-PullRequestTemplate -Content ($content -replace "`n", "`r`n")
        $result.Classifiers | Should -Be 5
    }

    It 'rejects <Name>' -ForEach $malformed {
        { Test-PullRequestTemplate -Content $Content } | Should -Throw -ExpectedMessage $ExpectedError
    }

    It 'rejects empty content rather than returning a pass' {
        { Test-PullRequestTemplate -Content '' } | Should -Throw -ExpectedMessage '*empty*'
    }

    It 'does not identify the unchanged legacy fallback as the candidate' {
        $legacy = "<!-- Lead with a concise outcome. -->`n---`n<details><summary>Technical details</summary></details>"
        { Test-PullRequestTemplate -Content $legacy } | Should -Throw -ExpectedMessage '*announcement marker*'
    }
}

Describe 'Actual committed validation inputs' {
    BeforeEach {
        $PSNativeCommandUseErrorActionPreference = $true
        $repositoryPath = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $repositoryPath
        git -C $repositoryPath init --quiet --initial-branch=main
        git -C $repositoryPath config user.name 'Validation fixture'
        git -C $repositoryPath config user.email 'fixture@example.invalid'
        git -C $repositoryPath config core.autocrlf false
        [IO.File]::WriteAllText((Join-Path -Path $repositoryPath -ChildPath 'base.md'), "# Base`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record anonymous base fixture'
        $baseRevision = git -C $repositoryPath rev-parse HEAD
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not create the anonymous Git fixture.'
        }
    }

    Describe 'Native local Markdown configuration' {
        It 'opens the provider-resolved configuration path with the native Node filesystem' {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath '..\linters\.markdown-lint.yml'
            $markdownConfig = (Resolve-Path -LiteralPath $configPath).ProviderPath
            node -e 'require("node:fs").readFileSync(process.argv[1], "utf8")' $markdownConfig
            $LASTEXITCODE | Should -Be 0
        }
    }

    It 'rejects an empty diff instead of counting self-tests as changed inputs' {
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*No applicable changed input*'
    }

    It 'rejects a media-only diff as no applicable input' {
        [IO.File]::WriteAllText((Join-Path -Path $repositoryPath -ChildPath 'image.png'), 'anonymous fixture')
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Add anonymous non-Markdown input'
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*No applicable changed input*'
    }

    It 'selects committed changed Markdown with spaces but not unchanged Markdown' {
        [IO.File]::WriteAllText((Join-Path -Path $repositoryPath -ChildPath 'changed file.md'), "# Changed`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Add changed Markdown input'
        $result = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $result.MarkdownFiles | Should -HaveCount 1
        $result.MarkdownFiles[0] | Should -BeExactly 'changed file.md'
        $result.TemplateFiles | Should -HaveCount 0
    }

    It 'rejects a filename containing <CaseName> before selecting otherwise valid inputs' -ForEach $unsupportedFilenames {
        $blob = git -C $repositoryPath rev-parse HEAD:base.md
        # Index-only paths exercise Unix names without creating invalid Windows files.
        git -C $repositoryPath -c core.protectNTFS=false update-index --add --cacheinfo "100644,$blob,$FileName"
        $changedMarkdownPath = Join-Path -Path $repositoryPath -ChildPath 'changed.md'
        [IO.File]::WriteAllText($changedMarkdownPath, "# Changed`n")
        git -C $repositoryPath add -- $changedMarkdownPath
        git -C $repositoryPath commit --quiet -m 'Record a control-character filename and valid Markdown'
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*control characters*'
    }

    It 'produces an exact relative filter without selecting an unchanged suffix path' {
        $directory = Join-Path -Path $repositoryPath -ChildPath 'docs'
        $null = New-Item -ItemType Directory -Path $directory
        $rootReadme = Join-Path -Path $repositoryPath -ChildPath 'README.md'
        [IO.File]::WriteAllText($rootReadme, "# Root`n")
        [IO.File]::WriteAllText((Join-Path -Path $directory -ChildPath 'README.md'), "# Nested`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record root and nested Markdown'
        $baseRevision = git -C $repositoryPath rev-parse HEAD
        [IO.File]::WriteAllText($rootReadme, "# Changed root`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Change only the root Markdown'
        $result = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $result.LintFilter | Should -BeExactly '^(README\.md)$'
        'README.md' | Should -Match $result.LintFilter
        'docs/README.md' | Should -Not -Match $result.LintFilter
    }

    It 'retains additions and deletions at lookup location <Location>' -ForEach $lookupLocations {
        $templatePath = Join-Path -Path $repositoryPath -ChildPath $Location
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $templatePath -Parent) -Force
        [IO.File]::WriteAllText($templatePath, $valid)
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Add a supported lookup template'
        $added = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $added.TemplateFiles | Should -Contain $Location
        $baseRevision = git -C $repositoryPath rev-parse HEAD
        Remove-Item -LiteralPath $templatePath
        [IO.File]::WriteAllText((Join-Path -Path $repositoryPath -ChildPath 'changed.md'), "# Changed`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Remove a supported lookup template'
        $removed = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $removed.TemplateFiles | Should -Contain $Location
    }

    It 'rejects a committed symbolic-link input even when Git materializes a regular file' {
        $path = Join-Path -Path $repositoryPath -ChildPath 'linked.md'
        [IO.File]::WriteAllText($path, $valid)
        $blob = git -C $repositoryPath hash-object -w $path
        git -C $repositoryPath config core.symlinks false
        git -C $repositoryPath update-index --add --cacheinfo "120000,$blob,linked.md"
        git -C $repositoryPath commit --quiet -m 'Record a symbolic-link input'
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*symbolic link*'
    }

    It 'rejects uncommitted content at <Location> instead of certifying HEAD' -ForEach $dirtyInputs {
        $path = Join-Path -Path $repositoryPath -ChildPath $Location
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $path -Parent) -Force
        [IO.File]::WriteAllText($path, $valid)
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record committed validation input'
        [IO.File]::WriteAllText($path, "# Uncommitted correction`n")
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*working tree*'
    }

    It 'rejects staged content that differs from the reported HEAD' {
        $path = Join-Path -Path $repositoryPath -ChildPath 'changed.md'
        [IO.File]::WriteAllText($path, "# Committed`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record committed Markdown'
        [IO.File]::WriteAllText($path, "# Staged correction`n")
        git -C $repositoryPath add --all
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision } |
            Should -Throw -ExpectedMessage '*working tree*'
    }

    It 'retains a deleted fallback as an applicable structural error' {
        $directory = Join-Path -Path $repositoryPath -ChildPath '.github'
        $null = New-Item -ItemType Directory -Path $directory
        $templatePath = Join-Path -Path $directory -ChildPath 'pull_request_template.md'
        [IO.File]::WriteAllText($templatePath, $valid)
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record the source-aligned fallback'
        $baseRevision = git -C $repositoryPath rev-parse HEAD
        Remove-Item -LiteralPath $templatePath
        [IO.File]::WriteAllText((Join-Path -Path $repositoryPath -ChildPath 'changed.md'), "# Changed`n")
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Remove the fallback while changing Markdown'
        $result = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $result.TemplateFiles | Should -Contain '.github/pull_request_template.md'
        $result.MarkdownFiles | Should -Not -Contain '.github/pull_request_template.md'
    }

    It 'retains the old path when a fallback is renamed outside template lookup' {
        $directory = Join-Path -Path $repositoryPath -ChildPath '.github'
        $null = New-Item -ItemType Directory -Path $directory
        $templatePath = Join-Path -Path $directory -ChildPath 'pull_request_template.md'
        [IO.File]::WriteAllText($templatePath, $valid)
        git -C $repositoryPath add --all
        git -C $repositoryPath commit --quiet -m 'Record the source-aligned fallback'
        $baseRevision = git -C $repositoryPath rev-parse HEAD
        $renamedPath = Join-Path -Path $directory -ChildPath 'renamed.md'
        git -C $repositoryPath mv -- $templatePath $renamedPath
        git -C $repositoryPath commit --quiet -m 'Move the fallback outside template lookup'
        $result = Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision $baseRevision
        $result.TemplateFiles | Should -Contain '.github/pull_request_template.md'
        $result.MarkdownFiles | Should -Contain '.github/renamed.md'
    }

    It 'fails explicitly for an invalid base revision' {
        { Get-ValidationInput -RepositoryPath $repositoryPath -BaseRevision 'missing-reference' } |
            Should -Throw -ExpectedMessage '*base revision*'
    }
}
