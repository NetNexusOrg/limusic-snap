# Limusic Snap

Unofficial community Snap package for [Limusic](https://github.com/SimoHypers/limusic),
a feature-rich desktop YouTube Music client built with Tauri, Rust and SvelteKit.

This repository is packaging-only. It does not vendor or fork the upstream
source; the build fetches the upstream `v1.3.0` tag from Git.

> Limusic is developed by SimoHypers and licensed under GPL-3.0. This Snap is
> not affiliated with or endorsed by the upstream author.

## Download

Prebuilt packages are published on the
[GitHub releases page](https://github.com/NetNexusOrg/limusic-snap/releases).
The current release is `v1.3.0`; download `limusic_1.3.0_amd64.snap` and its
`.sha256` file, then follow [Install locally](#install-locally).

## Requirements

- Ubuntu 24.04 or newer (the Snap uses `core24`)
- `snapcraft` 8 or newer
- LXD or Multipass for a clean build environment
- Network access during the build

Install the build tools:

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

The result is `limusic_1.3.0_amd64.snap`.

Building on the host with `--destructive-mode` is possible but only recommended
on a disposable Ubuntu 24.04 machine, because it installs build dependencies on
the host.

`snapcraft lint` reports unused-library warnings for optional dependencies pulled
in by `libmpv2` (for example `libjackserver`, `libflite_*`, `libcaca++` and
`libtheora`). They are left in place because they are transitive runtime
dependencies of libmpv and removing them selectively risks breaking playback
features. No metadata, desktop-entry or confinement warnings were reported.

`libblas3` and `liblapack3` are staged explicitly because `libsphinxbase3`
(transitively pulled in by libmpv) links against them. Their packages install
the libraries under `blas/` and `lapack/` and rely on `update-alternatives` for
the top-level soname symlinks, so the snap build creates those symlinks itself.

## Install locally

```bash
sudo snap install --dangerous ./limusic_1.3.0_amd64.snap
```

Connect removable media access if you keep music on external drives:

```bash
sudo snap connect limusic:removable-media
```

Run the app from the desktop menu or with:

```bash
limusic
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

Useful diagnostics:

```bash
snap connections limusic
sudo snap install snappy-debug
snappy-debug
snapcraft lint ./limusic_1.3.0_amd64.snap
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
The store name `limusic` must be registered and owned by the publisher before
the first upload:

```bash
snapcraft register limusic
snapcraft upload --release=edge ./limusic_1.3.0_amd64.snap
```

Install the published edge build on a test machine, run the checklist above,
then promote the tested revision:

```bash
sudo snap install limusic --edge
snapcraft release limusic <revision> stable
```

If the `limusic` name is unavailable, choose a store name and update `name`,
the desktop `Exec=`, and the documentation together. Automated CI builds are a
separate follow-up change; this packaging repository does not include a GitHub
Actions workflow yet.

## Strict-confinement limitations

- **Discord Rich Presence:** the host Discord IPC socket is outside the Snap's
  private runtime directory, and snapd has no interface for it. Rich Presence is
  unavailable; use the upstream `.deb` or AppImage if you need it.
- **Single instance:** the Tauri single-instance plugin cannot own its D-Bus
  name under strict confinement. The Snap sets `LIMUSIC_MULTI=1` to skip the
  plugin; two instances can run at the same time.
- **Start on login:** the Tauri autostart plugin writes inside the Snap's
  private home, not the host's `~/.config/autostart`. The host desktop will not
  read it.
- **Global shortcuts:** X11 works through the `x11` interface. On Wayland the
  desktop portal may ask for approval, so treat global shortcuts as best-effort.
- **Video codecs:** the GNOME content snap includes VP8/VP9/Opus and Matroska
  GStreamer plugins but not `libgstlibav`. H.264/AAC-only music videos may not
  play. Audio playback is unaffected because it uses libmpv.

## Credits

- [Limusic](https://github.com/SimoHypers/limusic) by SimoHypers, licensed
  GPL-3.0.
- Snap packaging maintained in
  [NetNexusOrg/limusic-snap](https://github.com/NetNexusOrg/limusic-snap).
- The GNOME Snapcraft extension provides the GTK 3 / WebKitGTK 4.1 runtime.
- libmpv is staged from Ubuntu 24.04 (`libmpv2` 0.37).

Report packaging issues at
<https://github.com/NetNexusOrg/limusic-snap/issues>. Report upstream
application bugs at <https://github.com/SimoHypers/limusic/issues>.
