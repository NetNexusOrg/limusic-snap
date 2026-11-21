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

The result is `limusic-community_1.4.1-4_amd64.snap`.

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

One patch is applied in `override-pull` with `git apply --check` and a hard
failure if it stops applying: `snap/local/disable-updater.patch` turns the
in-app Tauri updater off, so a strict Snap never offers to replace its own
files.

European Portuguese (`pt-PT`) is not patched in any more. Upstream added it to
the language picker in 1.5.0; builds pinned to 1.4.1 therefore show Brazilian
Portuguese only, and the picker gains `Português (Portugal)` as soon as the
`source-tag` moves to 1.5.0 or newer.

## Install a local build

```bash
sudo snap install --dangerous ./limusic-community_1.4.1-4_amd64.snap
sudo snap connect limusic-community:removable-media   # only for external drives
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
  `sudo snap connect limusic-community:removable-media` only when needed.
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
snapcraft lint ./limusic-community_1.4.1-4_amd64.snap
```

## Updates

Snapd owns updates. The upstream Tauri updater is disabled only in this Snap
build with a build-time patch, so the app never tries to replace its own files.
When the Snap is published, update it with:

```bash
sudo snap refresh limusic-community
```

For a local build, rebuild and reinstall with `--dangerous`.

## Publishing to the Snap Store

Publishing is prepared but **disabled**. The Snap is registered as
`limusic-community`; the name `limusic` belongs to another publisher
(`sidaliteir`, maintainer of `sidalit/limusic-snap`) and cannot be used.

Each workflow builds and publishes a GitHub Release. To also upload to the
store, set the repository variable `PUBLISH_TO_STORE` to `true` and add the
`SNAPCRAFT_STORE_CREDENTIALS` secret. The publish step then uploads the built
snap to `latest/<channel>`:

```bash
snapcraft register limusic-community
snapcraft upload --release=latest/edge ./limusic-community_1.4.1-4_amd64.snap
```

The `single-instance` D-Bus slot and `removable-media` may need review approval
before they can be used by a published Snap.

## Release channels

| Channel | Upstream source | Version scheme | Status |
| --- | --- | --- | --- |
| `stable` | latest stable tag | `<upstream>-<revision>` | automatic, daily |
| `candidate` | newest prerelease tag | `<upstream>-1` | automatic, daily |
| `beta` | `dev` branch | `git-dev-<sha7>` | dormant |
| `edge` | `master` branch | `git-<sha7>` | dormant |

`beta` and `edge` builds use `grade: devel` and pin the exact commit with
`source-commit`, so every release reproduces one tree. The branch builds are
not committed to `main`; only the stable bump is.

## Automation

Each channel has its own workflow, so schedules, permissions and failures are
independent:

- `.github/workflows/build-stable.yml` runs every day at 06:00 UTC;
- `.github/workflows/build-candidate.yml` runs every day at 06:00 UTC;
- `.github/workflows/build-beta.yml` and `build-edge.yml` are **dormant**: they
  only run on demand. Uncomment the `schedule` block in the file to activate
  them.

The workflows share three building blocks:

- `scripts/channel-release.sh <channel>` resolves the release tag and version,
  and prints `skip=true` when that release already exists;
- `build-snap.yml` prepares the source (bump for stable, prerelease tag for
  candidate, `source-commit` for branches), packs, lints and uploads the
  artifact;
- `publish-snap.yml` renders `docs/release-notes-template.md` and creates the
  GitHub release, optionally uploading to the Snap Store.

`stable` commits its bump to `main` with `[skip ci]`; `candidate`, `beta` and
`edge` build from a modified workspace without committing. A channel is skipped
when its release already exists. The `stable` release reuses the packaging
revision currently in the recipe, so a packaging-only fix publishes `v1.4.1-4`,
`v1.4.1-5` and so on without waiting for a new upstream tag.

To rebuild a channel:

```bash
gh workflow run build-stable.yml -f force=true
gh workflow run build-candidate.yml -f force=true
gh workflow run build-edge.yml -f force=true   # dormant channel
```

If any step fails, the workflow opens or comments on an issue titled
`Build <channel> failed`.

Running the scripts locally:

```bash
GITHUB_REPOSITORY=NetNexusOrg/limusic-snap ./scripts/channel-release.sh stable
./scripts/bump-upstream.sh v1.5.0
./scripts/prepare-prerelease.sh v1.5.0-rc.1
./scripts/switch-to-ref.sh dev
```

## Credits

- [Limusic](https://github.com/SimoHypers/limusic) by SimoHypers, licensed
  GPL-3.0.
- Snap packaging maintained in
  [NetNexusOrg/limusic-snap](https://github.com/NetNexusOrg/limusic-snap).
- The GNOME Snapcraft extension provides the GTK 3 / WebKitGTK 4.1 runtime.
- libmpv is staged from Ubuntu 24.04 (`libmpv2` 0.37).
- Screenshots in `docs/screenshots/` are from the upstream project.
