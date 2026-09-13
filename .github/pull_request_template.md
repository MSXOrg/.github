<!-- markdownlint-disable MD013 MD033 MD041 -->

<!--
Use one short reader-facing title. Omit icon, type, and Conventional Commit
prefixes; issue references; unrelated lists; and AI or agent attribution.

Replace every placeholder. Delete unused classifier groups, supporting blocks,
examples, and release fields. Keep retained classifier groups in the order
shown. Repeat a complete group when one classifier has several distinct results.

For internal-only work with no classified result, delete all five classifier
groups and place one applicable Technical details and Related references pair
directly after the marker.

Delete the complete Release decisions block when the target route does not
invoke Release Management, and apply no release:* labels. For an invoked route
with Release set to No, keep only Release and Labels with release:skip.

Follow the canonical [MSX PR Format](https://msxorg.github.io/docs/Ways-of-Working/PR-Format/).
-->

{{ One or two short summary paragraphs that state what changes, who is affected,
and any required action. }}

<!-- ANNOUNCEMENT STOP -->

## Breaking: {{ Reader-facing result }}

{{ One or two prose paragraphs that explain the outcome, affected readers, and
required action. }}

{{ Optional interface example or compact table after the prose. Delete when it
does not help the reader act. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence for this result. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed consumer or template change, record the
release and source baseline, exact consumer action and verification, and the
compatible template repository and immutable commit. Delete when it does not
apply. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Removed: {{ Reader-facing result }}

{{ One or two prose paragraphs that explain the outcome, affected readers, and
required action. }}

{{ Optional interface example or compact table after the prose. Delete when it
does not help the reader act. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence for this result. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed consumer or template change, record the
release and source baseline, exact consumer action and verification, and the
compatible template repository and immutable commit. Delete when it does not
apply. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## New: {{ Reader-facing result }}

{{ One or two prose paragraphs that explain the outcome, affected readers, and
required action. }}

{{ Optional interface example or compact table after the prose. Delete when it
does not help the reader act. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence for this result. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed consumer or template change, record the
release and source baseline, exact consumer action and verification, and the
compatible template repository and immutable commit. Delete when it does not
apply. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Changed: {{ Reader-facing result }}

{{ One or two prose paragraphs that explain the outcome, affected readers, and
required action. }}

{{ Optional interface example or compact table after the prose. Delete when it
does not help the reader act. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence for this result. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed consumer or template change, record the
release and source baseline, exact consumer action and verification, and the
compatible template repository and immutable commit. Delete when it does not
apply. }}

</details>

<details>
<summary>Related references</summary>

- Resolves MSXOrg/repository#123
- References MSXOrg/repository#456
- Depends on MSXOrg/other-repository#789

</details>

## Fixed: {{ Reader-facing result }}

{{ One or two prose paragraphs that explain the outcome, affected readers, and
required action. }}

{{ Optional interface example or compact table after the prose. Delete when it
does not help the reader act. }}

<details>
<summary>Technical details</summary>

{{ Implementation and validation evidence for this result. }}

| Changed surface | Standards checked | Framework docs checked | Result |
| --- | --- | --- | --- |
| `{{ Path or interface }}` | {{ Applicable standards }} | {{ Applicable framework docs, or `None (no framework-specific docs)` }} | {{ `Aligned`, `Fixed in this PR`, or `Exception - MSXOrg/repository#123` }} |

{{ For an applicable release-managed consumer or template change, record the
release and source baseline, exact consumer action and verification, and the
compatible template repository and immutable commit. Delete when it does not
apply. }}

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
  Delete this field when Release is No. }}
- **Mode:** {{ Stable or Prerelease }} - {{ Target-route or override evidence.
  Delete this field when Release is No. }}
- **Labels:** {{ Exact `release:*` labels, or `None` when effective configuration
  supplies the decision without an override label. }}

</details>
