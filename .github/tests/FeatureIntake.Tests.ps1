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
}
