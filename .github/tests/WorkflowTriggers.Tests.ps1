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
    $events = @(
        @{ Action = 'opened'; Base = 'main'; Expected = $true }
        @{ Action = 'synchronize'; Base = 'main'; Expected = $true }
        @{ Action = 'reopened'; Base = 'main'; Expected = $true }
        @{ Action = 'edited'; Base = 'main'; Expected = $true }
        @{ Action = 'edited'; Base = 'other'; Expected = $false }
    )
}

Describe 'Pull request validation trigger coverage' {
    BeforeAll {
        $path = Join-Path -Path $PSScriptRoot -ChildPath '..\workflows\Organization-Defaults-Validation.yml'
        $workflow = [IO.File]::ReadAllText($path) -replace '\r\n?', "`n"
        $trigger = [regex]::Match($workflow, "(?ms)^'on':\n  pull_request:\n(?<settings>.*?)(?=^\S)").Groups['settings'].Value
        if ([string]::IsNullOrWhiteSpace($trigger)) {
            throw 'The expected pull_request trigger is missing.'
        }
        $types = [regex]::Match($trigger, '(?m)^    types: \[(?<types>[^\]]+)\]$')
        $actions = @('opened', 'synchronize', 'reopened')
        if ($types.Success) {
            $actions = @($types.Groups['types'].Value -split ',\s*')
        }
        $branches = @([regex]::Matches($trigger, '(?m)^      - (?<branch>\S+)$') |
                ForEach-Object { $_.Groups['branch'].Value })
    }

    It 'covers anonymous <Action> activity targeting <Base>' -ForEach $events {
        # GitHub documents retargeting as edited; default activities exclude it.
        (($actions -contains $Action) -and ($branches -contains $Base)) | Should -Be $Expected
    }

    It 'retains the named read-only job and the actual-head checkout' {
        $workflow | Should -Match '(?m)^    name: Organization defaults validation$'
        $workflow | Should -Match '(?m)^      contents: read$'
        $workflow | Should -Match '(?m)^          persist-credentials: false$'
        $workflow | Should -Match 'ref: \$\{\{ github.event.pull_request.head.sha \}\}'
        $workflow | Should -Not -Match 'pull_request_target|workflow_dispatch'
    }

    It 'uses the released linter include-only contract after Markdown is checked separately' {
        $workflow | Should -Not -Match '(?m)^          VALIDATE_[A-Z_]+: false$'
        $workflow | Should -Match '(?m)^          VALIDATE_POWERSHELL: true$'
        $workflow | Should -Match 'Test-OrganizationDefaults.ps1'
    }
}
