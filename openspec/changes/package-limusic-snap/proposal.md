# Proposal

## Why

Limusic is distributed upstream as a `.deb`, `.rpm` and AppImage, but not as a
Snap. A Snap gives Ubuntu users transactional installs, automatic updates
through snapd, and confinement. This repository exists only to package the
upstream application; it must not fork or vendor the upstream source.

## What Changes

- Add a `core24` strict-confinement Snap recipe that builds upstream Limusic
  `v1.3.0` from its Git tag (the latest stable release; `v1.4.0-rc.7` is a
  prerelease and is not used).
- Build the SvelteKit UI with Node 22 + pnpm 10, then compile the Tauri/Rust
  backend with a stable Rust toolchain and Tauri CLI 2.11.5.
- Use the Snapcraft GNOME extension (`gnome`) for the GTK 3 / WebKitGTK 4.1
  runtime and build environment; stage `libmpv2` and its runtime dependencies,
  because libmpv is not provided by the extension.
- Install the application binary, a corrected `.desktop` file, an AppStream
  metainfo file, and hicolor icons into the snap.
- Disable the Tauri self-updater only in the Snap build, because snapd owns
  updates. This is done with a small build-time patch, not an upstream change.
- Inject the optional Last.fm API credentials at build time from a gitignored
  local file, and keep them out of the repository and out of `snapcraft.yaml`.
- Declare the minimum interfaces: `network`, `network-bind` (the app's loopback
  video proxy), `audio-playback`, `home`, `removable-media`, plus an `mpris`
  slot named `limusic`. The GNOME extension supplies `desktop`,
  `desktop-legacy`, `opengl`, `wayland`, `x11` and `gsettings`.
- Document the strict-confinement limitations: Discord Rich Presence cannot
  reach the host Discord IPC socket, single-instance D-Bus registration is not
  permitted, and start-on-login cannot write the host autostart directory.

## Capabilities

### New Capabilities

- `snap-package`: the buildable, installable Snap artifact, its upstream
  pinning, metadata, desktop integration, secret handling, and update model.
- `desktop-integration`: the runtime behavior and confinement boundaries for
  audio, media keys/MPRIS, tray, local music, networking, and known unsupported
  features.

### Modified Capabilities

None. This is a new packaging repository with no existing specs.

## Impact

- New repository files only: `snap/snapcraft.yaml`, `snap/local/*`,
  `.gitignore`, `README.md`, and the OpenSpec change.
- No upstream source is modified or committed. A Snap-only patch is applied to
  the fetched upstream tree at build time.
- Build dependencies: Node 22, pnpm 10, Rust stable, Tauri CLI 2.11.5,
  `build-essential`, `pkg-config`, `curl`, `ca-certificates`, `libmpv-dev`,
  `libssl-dev`, `libayatana-appindicator3-dev`, `libdbus-1-dev`, plus the GNOME
  SDK content snap.
- Runtime dependencies: `core24`, `gnome-46-2404`, `gtk-common-themes`,
  `mesa-2404`, and staged `libmpv2` libraries.
- CI and Snap Store publishing are explicitly out of scope for this change and
  are handled as separate follow-up tasks.
