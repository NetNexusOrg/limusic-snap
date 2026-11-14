## ADDED Requirements

### Requirement: Reproducible Snap build in CI

The repository MUST provide a GitHub Actions workflow that builds the Snap on
an Ubuntu 24.04 runner using LXD, without relying on a developer machine.

#### Scenario: Build on a relevant change

- **WHEN** a commit is pushed to `main`, a tag matching `v*` is pushed, a pull
  request changes `snap/**` or the workflow file, or the workflow is manually
  dispatched
- **THEN** the workflow runs on `ubuntu-24.04`
- **AND** it checks out the repository and sets up LXD
- **AND** it runs `snapcraft pack --use-lxd`
- **AND** the build produces a `limusic_*.snap` file

#### Scenario: Lint and checksum

- **WHEN** the snap has been built
- **THEN** the workflow runs `snapcraft lint` on the produced snap
- **AND** it writes a SHA-256 checksum next to the snap
- **AND** it uploads the snap and checksum as a workflow artifact

### Requirement: Optional Last.fm credentials

The workflow MUST NOT require Last.fm credentials and MUST NOT expose them in
logs or repository files.

#### Scenario: Secrets are configured

- **WHEN** both `LASTFM_API_KEY` and `LASTFM_API_SECRET` repository secrets are
  available
- **THEN** the workflow writes them to the gitignored
  `snap/local/lastfm.keys` before building
- **AND** the resulting snap includes Last.fm support

#### Scenario: Secrets are absent

- **WHEN** either secret is missing, including on fork pull requests
- **THEN** the workflow emits a warning
- **AND** the build continues without `snap/local/lastfm.keys`
- **AND** the resulting snap reports Last.fm as not configured

### Requirement: No automatic publishing

The workflow MUST stop at build, lint and artifact upload.

#### Scenario: A green CI run

- **WHEN** the build and lint steps succeed
- **THEN** the workflow does not upload to the Snap Store
- **AND** it does not create or modify a GitHub Release
