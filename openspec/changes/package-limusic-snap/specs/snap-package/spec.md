# Spec Delta

## Purpose

Defines the buildable and installable Limusic Snap: which upstream release it
packages, how it is built, what metadata it exposes, and how updates and
credentials are handled.

## ADDED Requirements

### Requirement: Upstream release pinning

The Snap MUST build from an immutable upstream Git tag and MUST report the same
version as that tag. The packaging repository MUST NOT vendor, clone, or modify
the upstream source in the repository.

#### Scenario: Latest stable release selected

- **WHEN** the packaging change is prepared
- **THEN** the selected tag is the latest stable upstream release (`v1.4.0` at
  the time of writing), not a release candidate or other prerelease
- **AND** `version` is `1.4.0-1` (packaging revision) and `source-tag` is `v1.4.0`

#### Scenario: Upstream has no submodules

- **WHEN** the build fetches the pinned tag
- **THEN** no `git submodule update` step is required because upstream has no
  `.gitmodules` at that tag

### Requirement: Reproducible two-stage build

The Snap build MUST build the SvelteKit UI before compiling the Rust/Tauri
backend, and MUST install the resulting application binary into the snap.

#### Scenario: UI and backend are built in order

- **WHEN** the part builds
- **THEN** `ui` dependencies are installed with pnpm 10 on Node 22 and the
  frontend is built before Cargo compiles the Tauri application
- **AND** the compiled `limusic-app` binary is installed at `bin/limusic-app`

#### Scenario: Tauri bundling is not used

- **WHEN** the backend is compiled
- **THEN** the build does not produce a `.deb`, `.rpm` or AppImage inside the
  Snap
- **AND** the desktop file, metainfo and icons are installed from
  `snap/local/` instead of from a Tauri bundle

### Requirement: Complete Snap metadata

The Snap metadata MUST identify the package as an unofficial community build
and MUST credit the upstream author.

#### Scenario: Store-facing metadata

- **WHEN** the Snap is inspected or published
- **THEN** `name` is `limusic`, `title` is `Limusic`, `license` is
  `GPL-3.0-only`, and `website` is `https://limusic.app`
- **AND** `source-code` points to `https://github.com/SimoHypers/limusic`
- **AND** `contact` and `issues` point to
  `https://github.com/NetNexusOrg/limusic-snap`
- **AND** the summary and description state that this is an unofficial Snap and
  credit the original author

#### Scenario: Desktop identity

- **WHEN** the Snap is installed
- **THEN** `common-id` is `limusic`, the desktop file is
  `usr/share/applications/limusic.desktop`, and an AppStream metainfo file with
  `<id>com.limusic.desktop</id>` is installed at
  `usr/share/metainfo/com.limusic.desktop.metainfo.xml`

### Requirement: Desktop file and icon resolution

The installed desktop entry MUST use an icon path that resolves inside the
Snap, not a bare icon name.

#### Scenario: Icon is rewritten to an absolute path

- **WHEN** the desktop file is installed
- **THEN** its `Icon=` value is an absolute path under
  `/usr/share/icons/hicolor/.../apps/limusic-app.png`
- **AND** the referenced icon file exists in the prime tree
- **AND** its `Exec` value is `limusic`, the snap app command, so snapd maps it to
  `/snap/bin/limusic`
- **AND** its `StartupWMClass` remains `limusic-app`, matching the window class
  set by the upstream Tauri binary

### Requirement: No credentials in the repository

The repository MUST NOT contain Last.fm API keys or any other secret. Build-time
credentials MUST come from a gitignored local file or the build environment.

#### Scenario: Credentials supplied locally

- **WHEN** `snap/local/lastfm.keys` exists at build time
- **THEN** its contents are copied to `src-tauri/lastfm.keys` before Cargo
  compiles the backend
- **AND** the file is listed in `.gitignore` and is never committed

#### Scenario: Credentials absent

- **WHEN** no credentials are supplied
- **THEN** the build still succeeds
- **AND** the Last.fm feature reports "not configured" at runtime

### Requirement: Snap-owned updates

The Snap MUST NOT attempt to download or install Tauri updates. Snapd is the
only update mechanism for the installed Snap.

#### Scenario: Updater disabled only for the Snap build

- **WHEN** the Snap build applies its build-time patch
- **THEN** the UI's update lookup returns no update and does not offer a
  self-install action
- **AND** the patch is applied only to the fetched build tree, leaving the
  upstream repository unchanged
- **AND** other distribution formats are unaffected

### Requirement: Build and install verification

The packaging MUST provide a documented, reproducible command sequence for
building and installing the Snap locally, and MUST pass `snapcraft lint` with no
unresolved relevant warnings.

#### Scenario: Local build and install

- **WHEN** a maintainer runs the documented `snapcraft pack` command in LXD or
  Multipass
- **THEN** a `limusic_1.4.0-1_amd64.snap` is produced
- **AND** it can be installed with
  `sudo snap install --dangerous ./limusic_1.4.0-1_amd64.snap`
- **AND** `snapcraft lint` has been run and its relevant findings addressed
