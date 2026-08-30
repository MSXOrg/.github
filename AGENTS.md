# Agent Instructions

This repository is `github.com/MSXOrg/.github`. Read in this order:

1. [README.md](README.md) — what this repository provides and how its defaults are enforced.
2. [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) — how a change is made and reviewed.
3. `~/.msxorg/docs/src/docs/index.md` — current MSXOrg organization standards.

Before reading the central docs, ensure `~/.msxorg/docs` is a clean checkout on
the remote default branch and exactly synchronized with it. Use Git commands
only to create or refresh the clone:

```git
git clone https://github.com/MSXOrg/docs.git ~/.msxorg/docs
git -C ~/.msxorg/docs fetch --prune origin
git -C ~/.msxorg/docs pull --ff-only
git -C ~/.msxorg/docs status --porcelain
git -C ~/.msxorg/docs config --local user.name "<your name>"
git -C ~/.msxorg/docs config --local user.email "<your email>"
```

The status must be empty before the clone is used. Configure Git identity
locally with `git -C ~/.msxorg/docs config --local ...`; do not rely on global
Git configuration.
