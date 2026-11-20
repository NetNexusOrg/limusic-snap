# Packaging notes

Technical documentation for the unofficial Limusic Snap. For installation, see
the [README](../README.md).

This repository is packaging-only. It does not vendor or fork the upstream
source; the build fetches the upstream `v1.4.1` tag from Git.

## Requirements

- Ubuntu 24.04 or newer (the Snap uses `core24`)
- `snapcraft` 8 or newer
- LXD or Multipass for a clean build environment
- Network access during the build

```bash
sudo snap install snapcraft --classic
sudo snap install lxd
lxd init --minimal
```

## Build

From the repository root:

```bash
snapcraft pack --use-lxd
```

The result is `limusic_1.4.1-2_amd64.snap`.

Building on the host with `--destructive-mode` is possible but only recommended
on a disposable Ubuntu 24.04 machine, because it installs build dependencies on
the host.

`snapcraft lint` reports unused-library warnings for optional dependencies pulled
in by `libmpv2` (for example `libjackserver`, `libflite_*`, `libcaca++` and
`libtheora`). They are left in place because they are transitive runtime
dependencies of libmpv and removing them selectively risks breaking playback
features. No metadata, desktop-entry or confinement warnings are reported.

`libblas3` and `liblapack3` are staged explicitly because `libsphinxbase3`
(transitively pulled in by libmpv) links against them. Their packages install
the libraries under `blas/` and `lapack/` and rely on `update-alternatives` for
the top-level soname symlinks, so the snap build creates those symlinks itself.

`gstreamer1.0-libav` is staged because the GNOME content snap ships the base
GStreamer plugins but not `libgstlibav`, which WebKitGTK needs for H.264/AAC
music videos. The GNOME `desktop-launch` adds `$SNAP/usr/lib/$ARCH/gstreamer-1.0`
to `GST_PLUGIN_PATH`, so the staged plugin is loaded automatically. It is built
against the same GStreamer 1.24 that `gnome-46-2404` provides.

## Install a local build

```bash
sudo snap install --dangerous ./limusic_1.4.1-2_amd64.snap
sudo snap connect limusic:removable-media   # only for external drives
```

## Last.fm credentials

Last.fm support is optional. The upstream build reads two compile-time values
from `src-tauri/lastfm.keys`; this Snap copies them from a local, gitignored
file before compiling.

```bash
cp snap/local/lastfm.keys.example snap/local/lastfm.keys
# edit snap/local/lastfm.keys with your own API key and secret
snapcraft pack --use-lxd
```

The file format is:

```text
LIMUSIC_LASTFM_API_KEY=...
LIMUSIC_LASTFM_API_SECRET=...
```

`snap/local/lastfm.keys` is ignored by Git and must never be committed. If it is
absent, the build still succeeds and Last.fm reports “not configured” in the
app.

The values are compiled into the resulting binary. Do not distribute or publish
a Snap built with credentials you do not want embedded; use your own keys for
local builds.

## CI

`.github/workflows/build-snap.yml` builds the Snap on `ubuntu-24.04` with
`canonical/setup-lxd@v1` and `snapcraft pack --use-lxd`, runs `snapcraft lint`,
writes a SHA-256 checksum and uploads both files as the `limusic-snap` workflow
artifact. It runs on pushes to `main`, `v*` tags, pull requests touching
`snap/**` or the workflow, and manual dispatch.

Last.fm is optional in CI: when the repository secrets `LASTFM_API_KEY` and
`LASTFM_API_SECRET` exist, the workflow writes the gitignored
`snap/local/lastfm.keys` before building; otherwise it emits a warning and
builds without Last.fm support. CI never publishes to the Snap Store or creates
a GitHub Release.

## Interfaces

The Snap declares the minimum needed for its documented behavior:

- `network` — YouTube Music, Last.fm and network playback.
- `network-bind` — the app's loopback video/audio proxies.
- `network-status` — lets WebKit's desktop-portal proxy/network lookup see that
  the Snap has network access. Without this marker interface, Google login fails
  with `org.freedesktop.portal.Error.NotAllowed: This call is not available
  inside the sandbox`. It is auto-connected and grants no payload access.
- `audio-playback` — libmpv output through PulseAudio/PipeWire.
- `home` — local music in non-hidden home directories.
- `removable-media` — local music on removable volumes. snapd does not
  auto-connect this interface for public snaps; connect it manually with
  `sudo snap connect limusic:removable-media` only when needed.
- `mpris` slot — owns `org.mpris.MediaPlayer2.limusic` for media keys/widgets.
- `single-instance` slot — session D-Bus name
  `com.limusic.desktop.SingleInstance`, owned by the Tauri single-instance
  plugin. A second launch hands its arguments to the running window instead of
  starting a new process. Publishing the Snap requires store approval for this
  name.

Desktop, display, GPU and settings interfaces come from the GNOME extension.

## Limitations under strict confinement

- **Discord Rich Presence:** the host Discord IPC socket is outside the Snap's
  private runtime directory, and snapd has no interface for it. Rich Presence is
  unavailable; use the upstream `.deb` or AppImage if you need it.
- **Start on login:** the Tauri autostart plugin writes inside the Snap's
  private home, not the host's `~/.config/autostart`. The host desktop will not
  read it.
- **Global shortcuts:** X11 works through the `x11` interface. On Wayland the
  desktop portal may ask for approval, so treat global shortcuts as best-effort.
- **Karaoke:** the vocal-removal models download into the Snap's private data
  directory, which works, but GPU acceleration is best-effort. It depends on
  Vulkan/DRM access provided by the GNOME extension and has not been validated
  under strict confinement; CPU processing always remains available.
- **wallust / pywal palettes:** both read dotfiles (`~/.cache/wal`,
  `~/.config/wallust`), which the `home` interface does not expose. Only the
  built-in palettes and artwork-derived colors work in the Snap.
- **Memory-pressure telemetry:** WebKit's `PressureMonitor` cannot read
  `/proc/zoneinfo` or the Snap's cgroup `memory.current` under strict
  confinement, so AppArmor logs repeated denials. Playback and the UI are
  unaffected. No broad `system-observe` plug is added for this optional signal.

## Verification checklist

After installing:

- [ ] The app opens and the window renders.
- [ ] Google login loads in the WebKit view.
- [ ] Audio playback works.
- [ ] Media keys and the desktop media widget control playback through MPRIS.
- [ ] The tray icon appears on a desktop with a StatusNotifierWatcher.
- [ ] Local music under `$HOME` plays.
- [ ] Local music on a connected removable volume plays.
- [ ] Discord Rich Presence fails soft without crashing the app.
- [ ] The in-app updater does not offer a Tauri update.
- [ ] Last.fm works when keys are present, or reports “not configured” without
      them.
- [ ] A karaoke model downloads and vocal removal starts (best-effort under
      confinement).

Useful diagnostics:

```bash
snap connections limusic
sudo snap install snappy-debug
snappy-debug
snapcraft lint ./limusic_1.4.1-2_amd64.snap
```

## Updates

Snapd owns updates. The upstream Tauri updater is disabled only in this Snap
build with a build-time patch, so the app never tries to replace its own files.
When the Snap is published, update it with:

```bash
sudo snap refresh limusic
```

For a local build, rebuild and reinstall with `--dangerous`.

## Publishing to the Snap Store

Publishing is a separate step and is not required to build or test the Snap.
**The store name `limusic` is already registered by another publisher**
(`sidaliteir`, maintainer of `sidalit/limusic-snap`), so this project cannot
claim it; an upload under that name would be rejected.

The options are:

1. **Publish under a different name**, for example `limusic-community`. That
   requires changing `name` in `snap/snapcraft.yaml`, the `Exec=` line in
   `snap/local/limusic.desktop`, and every command in this documentation, then
   registering the new name:

   ```bash
   snapcraft register limusic-community
   snapcraft upload --release=edge ./limusic_1.4.1-2_amd64.snap
   ```

2. **Ask the current owner to transfer the name** or to invite this account as
   a collaborator. Only the owner can do that.

3. **Keep distributing through GitHub Releases** with
   `snap install --dangerous`, as today. Updates are then manual: download the
   new snap and reinstall it.

The `single-instance` D-Bus slot also needs store approval if the Snap is
published, because it claims a name in the `com.limusic.desktop` namespace.

Install a published edge build on a test machine, run the checklist above, then
promote the tested revision:

```bash
sudo snap install <store-name> --edge
snapcraft release <store-name> <revision> stable
```

## Automation

`.github/workflows/upstream-release.yml` checks `SimoHypers/limusic` every day
at 06:00 UTC for the latest stable release. When a version has no release here
yet, it:

1. bumps the packaging with `scripts/bump-upstream.sh <upstream-tag>`;
2. builds the Snap through the reusable `build-snap.yml` workflow, with the same
   Last.fm secrets;
3. commits the bump to `main` with `[skip ci]`;
4. creates a public GitHub release `v<upstream>-1` with the snap and checksum.

The Snap version stays `<upstream>-1`; the `-1` is the packaging revision for
that upstream release. Prereleases are ignored automatically because the
workflow reads the upstream `releases/latest`.

To release a specific tag, or to retry a failed version:

```bash
gh workflow run upstream-release.yml -f tag=v1.5.0
gh workflow run upstream-release.yml -f tag=v1.5.0 -f force=true
```

If any step fails, the workflow opens or comments on an issue titled
`Upstream release failed for <tag>` instead of publishing a partial release.

Running the bump locally is the same command:

```bash
./scripts/bump-upstream.sh v1.5.0
```

Nothing is published to the Snap Store automatically.

## Credits

- [Limusic](https://github.com/SimoHypers/limusic) by SimoHypers, licensed
  GPL-3.0.
- Snap packaging maintained in
  [NetNexusOrg/limusic-snap](https://github.com/NetNexusOrg/limusic-snap).
- The GNOME Snapcraft extension provides the GTK 3 / WebKitGTK 4.1 runtime.
- libmpv is staged from Ubuntu 24.04 (`libmpv2` 0.37).
- Screenshots in `docs/screenshots/` are from the upstream project.
