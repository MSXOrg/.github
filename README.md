# MSXOrg community defaults

`MSXOrg/.github` is GitHub's special public repository for organization-wide
community defaults. GitHub uses these files when an MSX repository does not
define its own corresponding file. This repository must remain public for the
fallback behavior to work.

The central [MSX documentation](https://msx.no/docs/) is the source for MSX
standards and ways of working.

The [pull request template](.github/pull_request_template.md) supplies a complete,
release-note-ready description scaffold and records its verified immutable
source. Repositories using this fallback need no configuration, code, or invocation changes;
authors fill in the inherited scaffold when opening a pull request. A repository's
local template retains precedence. Existing open pull request descriptions are not rewritten.
