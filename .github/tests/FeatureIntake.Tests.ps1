#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester executes setup and test blocks in separate scopes.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    $formPath = Join-Path -Path $PSScriptRoot -ChildPath '..\ISSUE_TEMPLATE\10-feature.yml'
    $content = [IO.File]::ReadAllText($formPath) -replace '\r\n?', "`n"
    $shape = @'
\A---
# GitHub issue form syntax and schema\.
name: (?<Name>[^\n]+)
description: (?<Description>[^\n]+)
title: '(?<Title>[^'\n]+)'
labels: \['feature', 'triage'\]
body:
  - type: markdown
    attributes:
      value: \|
(?<Guidance>(?:        [^\n]*\n|\n)+)  - type: textarea
    id: description
    attributes:
      label: (?<Label>[^\n]+)
      description: \|
(?<Prompt>(?:        [^\n]*\n)+)    validations:
      required: true\n\z
'@
    $form = [regex]::Match($content, ($shape -replace '\r\n?', "`n"))
    $introduction = $form.Groups['Guidance'].Value -replace '(?m)^ {8}', ''
    $guidance = ($introduction -replace '\s+', ' ').Trim()
    $prompt = ($form.Groups['Prompt'].Value -replace '\s+', ' ').Trim()
    $configurationPath = Join-Path -Path $PSScriptRoot -ChildPath '..\ISSUE_TEMPLATE\config.yml'
    $configuration = [IO.File]::ReadAllText($configurationPath) -replace '\r\n?', "`n"
}

Describe 'Organization feature intake' {
    It 'preserves the feature identity and triage routing without assigning a native type' {
        $form.Groups['Name'].Value | Should -BeExactly "`u{1F680} [Feature]"
        $form.Groups['Description'].Value | Should -BeExactly 'Suggest/request a new feature'
        $form.Groups['Title'].Value | Should -BeExactly "`u{1F680}[Feature]: "
        $content | Should -Match "(?m)^labels: \['feature', 'triage'\]$"
        $content | Should -Not -Match '(?m)^type:'
    }

    It 'retains the supported whole-form metadata and markdown and textarea structure' {
        $form.Success | Should -BeTrue
        $guidance | Should -Not -BeNullOrEmpty
        $form.Groups['Label'].Value | Should -Not -BeNullOrEmpty
        $prompt | Should -Not -BeNullOrEmpty
    }

    It 'requires only the existing free-text description field' {
        [regex]::Matches($content, '(?m)^  - type: (?!markdown$)').Count | Should -Be 1
        $content | Should -Match '(?m)^    id: description$'
        $content | Should -Match '(?m)^      required: true$'
        $form.Success | Should -BeTrue
    }

    It 'keeps blank feedback intake available' {
        $configuration | Should -BeExactly "blank_issues_enabled: true`n"
    }

    It 'asks for the consumer need and who benefits' {
        $form.Groups['Label'].Value | Should -BeExactly 'Describe the need'
        $prompt | Should -Match ([regex]::Escape('What are you trying to do, and who would benefit?'))
    }

    It 'asks why the need matters' {
        $prompt | Should -Match ([regex]::Escape('Why does this matter? Describe the problem or opportunity.'))
    }

    It 'asks for a plain-language situation, action, and expected result' {
        $scenario = 'What should happen? Give a short example of the situation, ' +
        'the action you take, and the result you expect.'
        $prompt | Should -Match ([regex]::Escape($scenario))
        "$guidance $prompt" | Should -Not -Match '\bGherkin\b|\bGiven\s*/\s*When\s*/\s*Then\b'
    }

    It 'asks for a failure or boundary example only when it matters' {
        $boundary = 'If a failure or limit changes what you expect, include that example too.'
        $prompt | Should -Match ([regex]::Escape($boundary))
    }

    It 'links canonical planning and native routing instead of copying the guidance' {
        $guidance | Should -Match ([regex]::Escape('See [issue planning][planning] and [issue routing][routing].'))
        $planningLink = '[planning]: https://msx.no/docs/Ways-of-Working/Issues/Process/Planning/'
        $guidance | Should -Match ([regex]::Escape($planningLink))
        $routingLink = '[routing]: https://msx.no/docs/Ways-of-Working/Issues/Types/Hierarchy/'
        $guidance | Should -Match ([regex]::Escape($routingLink))

        $html = (ConvertFrom-Markdown -InputObject $introduction).Html
        $links = [regex]::Matches($html, '<a href="([^"]+)"')
        $links.Count | Should -Be 2
        $links[0].Groups[1].Value | Should -BeExactly 'https://msx.no/docs/Ways-of-Working/Issues/Process/Planning/'
        $links[1].Groups[1].Value | Should -BeExactly 'https://msx.no/docs/Ways-of-Working/Issues/Types/Hierarchy/'
    }

    It 'keeps external feedback separate from internal planning work' {
        $routing = 'This form collects feedback. Maintainers will link any internal planning work separately.'
        $guidance | Should -Match ([regex]::Escape($routing))
    }

    It 'does not require a technical solution or a special submission format' {
        $reassurance = 'You do not need to propose a technical solution or use a special format.'
        $guidance | Should -Match ([regex]::Escape($reassurance))
    }

    It 'does not solicit implementation choices or alternatives' {
        $prompt | Should -Not -Match '\b(implement(?:ation|ed)?|alternatives?)\b'
    }
}
