<!-- markdownlint-disable MD013 MD033 MD041 -->

<!--
Use one short reader-facing title. Omit icon, type, and Conventional Commit
prefixes; issue references; unrelated lists; and AI or agent attribution.

Replace every placeholder. Delete unused classifier groups, supporting blocks,
examples, and release fields. Keep retained classifier groups in the order
shown. Repeat a complete group when one classifier has several distinct results.
Use fully qualified references and closing keywords only for issues the complete
change resolves.

For internal-only work with no classified result, delete all five classifier
groups and place one applicable Technical details and Related references pair
directly after the marker. The summary carries the adoption or explicit no-action
result; the supporting pair carries applicable evidence.

Keep consumer instructions in the result prose and examples. Technical details
and references support but do not replace them. Keep version-specific migration
instructions in the PR/release notes, not repository migration guides. Cover
the complete delivered range from the identified consumer baseline, including
bundled changes and required intermediate operations.

The full body remains the release note. A future Discord sender takes only the
pre-marker segment; announcement automation and date strategies are not
implemented here. Keep exactly one marker after the leading summary.

Shared defaults are overridden by repository settings in the optional
.github/release.config.yml, then by explicitly supplied supported caller inputs.
Omitted caller inputs preserve repository settings. DefaultBump replaces
patch-only AutoPatching; it accepts patch, minor, or major, and its shared default is `patch`.
One explicit bump label overrides a valid effective DefaultBump. Invalid settings
and conflicting owned labels are errors, not reasons to select a fallback.

Use only release:patch, release:minor, release:major, release:prerelease, and
release:skip for release decisions. Prerelease is a mode using an explicit or
default bump, not another level. Skip stands alone.

Determine applicability from actual versioned release behavior, including native producer routes;
a missing settings file alone does not mean that a route is unmanaged.
Verify the immutable producer revision's settings and owned-label mapping before
using canonical signals. If the released interface differs, require a verified adapter
or producer/configuration migration with exact actions in that producer's
PR/release record. Unsupported signals block finalization and required decision
validation; do not apply ignored labels or treat the producer as unmanaged.
Delete the complete Release decisions block when the target route does not
invoke Release Management, and apply no release:* labels. For an invoked route
with Release set to No, keep only Release and Labels with release:skip.

Verified producer candidate: MSXOrg/docs#209 at 3d388e283c2e20d88d112b2951c4df857e955821.
The complete body below matches that candidate; this correspondence does not
claim that its draft has shipped.

Follow the [complete MSX PR Format candidate](https://github.com/MSXOrg/docs/blob/3d388e283c2e20d88d112b2951c4df857e955821/src/docs/Ways-of-Working/PR-Format.md#copy-the-complete-template).
Resolve [settings and caller overrides](https://github.com/MSXOrg/docs/blob/3d388e283c2e20d88d112b2951c4df857e955821/src/docs/Capabilities/release-management/design.md#settings-and-caller-overrides).
Keep [release evidence](https://github.com/MSXOrg/docs/blob/3d388e283c2e20d88d112b2951c4df857e955821/src/docs/Capabilities/release-management/spec.md#release-evidence) with its result.
-->

{{ One or two short summary paragraphs that state what changes, why, who is
affected, and required adoption actions or an explicit no-action result. }}

<!-- ANNOUNCEMENT STOP -->

## Breaking: {{ Reader-facing result }}

{{ Explain what changes, why, affected supported uses, compatibility, and exact
adoption actions or an explicit no-action result. Include applicable
prerequisites, verification, ordering, and any required intermediate installation
or run. }}

{{ Interface or old-to-new example, comparison, or diagram after the prose when
needed to make adoption unambiguous. Keep required transition details in this
note; link to evergreen usage docs only for optional depth. Delete when prose
is sufficient. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence, closing delivery-leaf plan progress,
and issue-convergence search scope and outcome for this result, even when no
additional issue converges. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed result, identify the consumer-change release
and source baseline and evidence supporting the actions or no-action result
above. For an affected integration template, identify its repository, verified
compatible immutable commit, and compatibility evidence. Publication resolves
actual release coordinates; do not predict a final version. Delete inapplicable
evidence. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Removed: {{ Reader-facing result }}

{{ Explain what changes, why, affected supported uses, compatibility, and exact
adoption actions or an explicit no-action result. Include applicable
prerequisites, verification, ordering, and any required intermediate installation
or run. }}

{{ Interface or old-to-new example, comparison, or diagram after the prose when
needed to make adoption unambiguous. Keep required transition details in this
note; link to evergreen usage docs only for optional depth. Delete when prose
is sufficient. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence, closing delivery-leaf plan progress,
and issue-convergence search scope and outcome for this result, even when no
additional issue converges. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed result, identify the consumer-change release
and source baseline and evidence supporting the actions or no-action result
above. For an affected integration template, identify its repository, verified
compatible immutable commit, and compatibility evidence. Publication resolves
actual release coordinates; do not predict a final version. Delete inapplicable
evidence. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## New: {{ Reader-facing result }}

{{ Explain what changes, why, affected supported uses, compatibility, and exact
adoption actions or an explicit no-action result. Include applicable
prerequisites, verification, ordering, and any required intermediate installation
or run. }}

{{ Interface or old-to-new example, comparison, or diagram after the prose when
needed to make adoption unambiguous. Keep required transition details in this
note; link to evergreen usage docs only for optional depth. Delete when prose
is sufficient. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence, closing delivery-leaf plan progress,
and issue-convergence search scope and outcome for this result, even when no
additional issue converges. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed result, identify the consumer-change release
and source baseline and evidence supporting the actions or no-action result
above. For an affected integration template, identify its repository, verified
compatible immutable commit, and compatibility evidence. Publication resolves
actual release coordinates; do not predict a final version. Delete inapplicable
evidence. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Changed: {{ Reader-facing result }}

{{ Explain what changes, why, affected supported uses, compatibility, and exact
adoption actions or an explicit no-action result. Include applicable
prerequisites, verification, ordering, and any required intermediate installation
or run. }}

{{ Interface or old-to-new example, comparison, or diagram after the prose when
needed to make adoption unambiguous. Keep required transition details in this
note; link to evergreen usage docs only for optional depth. Delete when prose
is sufficient. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence, closing delivery-leaf plan progress,
and issue-convergence search scope and outcome for this result, even when no
additional issue converges. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed result, identify the consumer-change release
and source baseline and evidence supporting the actions or no-action result
above. For an affected integration template, identify its repository, verified
compatible immutable commit, and compatibility evidence. Publication resolves
actual release coordinates; do not predict a final version. Delete inapplicable
evidence. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Fixed: {{ Reader-facing result }}

{{ Explain what changes, why, affected supported uses, compatibility, and exact
adoption actions or an explicit no-action result. Include applicable
prerequisites, verification, ordering, and any required intermediate installation
or run. }}

{{ Interface or old-to-new example, comparison, or diagram after the prose when
needed to make adoption unambiguous. Keep required transition details in this
note; link to evergreen usage docs only for optional depth. Delete when prose
is sufficient. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence, closing delivery-leaf plan progress,
and issue-convergence search scope and outcome for this result, even when no
additional issue converges. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed result, identify the consumer-change release
and source baseline and evidence supporting the actions or no-action result
above. For an affected integration template, identify its repository, verified
compatible immutable commit, and compatibility evidence. Publication resolves
actual release coordinates; do not predict a final version. Delete inapplicable
evidence. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

<details>
<summary>Release decisions</summary>

- **Release:** {{ Yes or No }} - {{ Evidence from the artifact, route, and
  supported consumer contract. }}
- **Version bump:** {{ Patch, Minor, or Major }} - {{ Compatibility evidence.
  Identify the explicit label, supported caller input, repository setting, or
  documented shared default that supplies it. Delete this field when Release
  is No. }}
- **Mode:** {{ Stable or Prerelease }} - {{ Target-route or override evidence.
  Identify configured release-candidate routing when applicable. Delete this
  field when Release is No. }}
- **Labels:** {{ Exact `release:*` labels, or `None` when effective configuration
  supplies the decision without an override label. }}

</details>
