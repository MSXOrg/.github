#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }
#Requires -Modules @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester executes setup and test blocks in separate scopes.'
)]
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

BeforeAll {
    $formPath = Join-Path -Path $PSScriptRoot -ChildPath '..\ISSUE_TEMPLATE\10-feature.yml'
    $form = ConvertFrom-Yaml -Yaml ([IO.File]::ReadAllText($formPath))
    $guidance = ($form.body[0].attributes.value -replace '\s+', ' ').Trim()
    $prompt = ($form.body[1].attributes.description -replace '\s+', ' ').Trim()
    $configurationPath = Join-Path -Path $PSScriptRoot -ChildPath '..\ISSUE_TEMPLATE\config.yml'
    $configuration = ConvertFrom-Yaml -Yaml ([IO.File]::ReadAllText($configurationPath))
}

Describe 'Organization feature intake' {
    It 'preserves the feature identity and triage routing without assigning a native type' {
        $form.name | Should -BeExactly "`u{1F680} [Feature]"
        $form.description | Should -BeExactly 'Suggest/request a new feature'
        $form.title | Should -BeExactly "`u{1F680}[Feature]: "
        @($form.labels).Count | Should -Be 2
        $form.labels[0] | Should -BeExactly 'feature'
        $form.labels[1] | Should -BeExactly 'triage'
        $form.ContainsKey('type') | Should -BeFalse
    }

    It 'uses valid GitHub form keys and markdown and textarea attributes' {
        ($form.Keys | Sort-Object) -join ',' | Should -BeExactly 'body,description,labels,name,title'
        @($form.body).Count | Should -Be 2

        $introduction = $form.body[0]
        $introduction.type | Should -BeExactly 'markdown'
        ($introduction.Keys | Sort-Object) -join ',' | Should -BeExactly 'attributes,type'
        @($introduction.attributes.Keys) | Should -Be @('value')
        $introduction.attributes.value | Should -BeOfType ([string])
        $introduction.attributes.value | Should -Not -BeNullOrEmpty

        $field = $form.body[1]
        $field.type | Should -BeExactly 'textarea'
        ($field.Keys | Sort-Object) -join ',' | Should -BeExactly 'attributes,id,type,validations'
        $field.id | Should -Match '^[A-Za-z0-9_-]+$'
        ($field.attributes.Keys | Sort-Object) -join ',' | Should -BeExactly 'description,label'
        $field.attributes.label | Should -BeOfType ([string])
        $field.attributes.label | Should -Not -BeNullOrEmpty
        $field.attributes.description | Should -BeOfType ([string])
        $field.attributes.description | Should -Not -BeNullOrEmpty
        @($field.validations.Keys) | Should -Be @('required')
        $field.validations.required | Should -BeOfType ([bool])
    }

    It 'requires only the existing free-text description field' {
        $fields = @($form.body | Where-Object { $_.type -ne 'markdown' })
        $fields.Count | Should -Be 1
        $fields[0].id | Should -BeExactly 'description'
        $fields[0].type | Should -BeExactly 'textarea'
        $fields[0].validations.required | Should -BeTrue
        $fields[0].attributes.ContainsKey('value') | Should -BeFalse
    }

    It 'keeps blank feedback intake available' {
        @($configuration.Keys) | Should -Be @('blank_issues_enabled')
        $configuration.blank_issues_enabled | Should -BeOfType ([bool])
        $configuration.blank_issues_enabled | Should -BeTrue
    }

    It 'asks for the consumer need and who benefits' {
        $form.body[1].attributes.label | Should -BeExactly 'Describe the need'
        $prompt | Should -Match ([regex]::Escape('What are you trying to do, and who would benefit?'))
    }

    It 'asks why the need matters' {
        $prompt | Should -Match ([regex]::Escape('Why does this matter? Describe the problem or opportunity.'))
    }

    It 'asks for a plain-language situation, action, and expected result' {
        $scenario = 'What should happen? Give a short example of the situation, ' +
        'the action you take, and the result you expect.'
        $prompt | Should -Match ([regex]::Escape($scenario))
        "$guidance $prompt" | Should -Not -Match '\b(Gherkin|Given|When|Then)\b'
    }

    It 'links the canonical issue and planning guidance instead of copying it' {
        $guidance | Should -Match ([regex]::Escape('See [MSX issues][issues] and [issue planning][planning].'))
        $guidance | Should -Match ([regex]::Escape('[issues]: https://msx.no/docs/Ways-of-Working/Issues/'))
        $planningLink = '[planning]: https://msx.no/docs/Ways-of-Working/Issues/Process/Planning/'
        $guidance | Should -Match ([regex]::Escape($planningLink))
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
