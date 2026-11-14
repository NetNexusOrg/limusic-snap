# Design

## Context

Limusic is a Tauri 2 application: a SvelteKit frontend in `ui/` and a Rust
workspace in `src-tauri/` plus `crates/`. Upstream publishes `v1.3.0` as the
latest stable release; `v1.4.0-rc.7` is a prerelease. The `v1.3.0` tree has no
`.gitmodules`, so no submodule handling is needed.

The Linux build dynamically links WebKitGTK 4.1, GTK 3 and libmpv. Upstream
documents Rust stable, Node, pnpm, `libmpv-dev`, `libwebkit2gtk-4.1-dev`,
`libgtk-3-dev`, `librsvg2-dev`, `libssl-dev` and `libdbus-1-dev`, and builds
with `cargo tauri build`. The released `.deb` contains only
`/usr/bin/limusic-app`, `usr/share/applications/limusic.desktop`, and hicolor
icons; it has no AppStream metainfo. Its desktop entry uses
`Icon=limusic-app` and `Exec=limusic-app`.

The Snapcraft GNOME extension for `core24` uses the `gnome-46-2404-sdk` build
snap and the `gnome-46-2404` content snap. It adds `desktop`, `desktop-legacy`,
`opengl`, `wayland`, `x11` and `gsettings`, binds WebKitGTK 4.1 from the content
snap, and supplies the GTK/WebKit build environment. The content snap also
contains GStreamer 1.24 plugins including VP8/VP9, Opus, Matroska, PulseAudio
and PipeWire. The `core24` base provides OpenSSL 3 (`libssl.so.3`,
`libcrypto.so.3`). libmpv is not in either, so it must be staged.

Strict confinement changes three upstream behaviors: the Tauri updater is
redundant with snapd, the Tauri single-instance plugin cannot own its D-Bus
name, and the Tauri autostart plugin cannot write the host's autostart
directory. Discord Rich Presence cannot reach the host's IPC socket. The design
must document these rather than invent interfaces.

## Goals / Non-Goals

**Goals:**

- Produce a `core24`/`strict`/`amd64` Snap from upstream `v1.3.0` with no
  vendored source.
- Build the UI and backend reproducibly with documented tool versions.
- Provide accurate metadata, desktop entry, AppStream metainfo and icons.
- Keep Last.fm credentials out of the repository.
- Make the Snap update only through snapd.
- Declare the minimum interfaces and explain every one.

**Non-Goals:**

- Forking upstream or adding a permanent snap-specific feature flag upstream.
- Shipping a `.deb`/AppImage inside the Snap.
- Making Discord RPC, host autostart, or single-instance D-Bus work under
  strict confinement.
- CI and Snap Store publishing; these are separate follow-up changes.

## Decisions

### 1. Pin upstream `v1.3.0`

Use `source: https://github.com/SimoHypers/limusic.git` with
`source-tag: v1.3.0` and `version: "1.3.0"`. The release-candidate line is
excluded because the snap is `grade: stable`. No `source-depth` is required,
but a shallow fetch is acceptable; the tag is immutable.

**Alternatives:** `v1.4.0-rc.7` (rejected: prerelease); tracking `master`
(rejected: not reproducible, unstable).

### 2. Use the GNOME extension, stage only libmpv

`apps.limusic.extensions: [gnome]` gives the correct GTK 3 / WebKitGTK 4.1
build and runtime stack and the desktop/GPU/display interfaces. It avoids staging a second copy
of WebKit, GTK, GStreamer, or Mesa, which would duplicate the content snap and
risk ABI mismatches.

`stage-packages` contains `libmpv2`, `libblas3` and `liblapack3`.
Snapcraft resolves `libmpv2`'s runtime dependencies (FFmpeg, libass,
PulseAudio, PipeWire, JACK, etc.). `libmpv2` in noble is 0.37.0, above
upstream's 0.35 minimum. `libsphinxbase3`, pulled in transitively by libmpv,
links against `libblas.so.3` and `liblapack.so.3`; Snapcraft does not stage
the virtual providers, so `libblas3` and `liblapack3` are explicit. Both
packages install their libraries under `blas/` and `lapack/` and rely on
`update-alternatives` for the top-level soname symlinks, which Snapcraft does
not run; `override-build` creates those symlinks explicitly.
`libssl3t64` is not staged because `core24` already provides OpenSSL 3.
`libayatana-appindicator` is not staged because upstream's Linux tray uses
`ksni` and the binary has no `DT_NEEDED` entry for it. If a future upstream
build unexpectedly links it, add `libayatana-appindicator3-1` to
`stage-packages` and re-test the tray.

**Alternatives:** stage `libwebkit2gtk-4.1-0`, `libgtk-3-0`, GStreamer plugins
(rejected: duplicates the GNOME content snap); use the KDE extension (rejected:
the app is GTK/WebKit, not Qt).

### 3. Build with the upstream toolchain, without Tauri bundling

Use a `nil` plugin with the upstream Git source. In `override-build`:

1. Install stable Rust with rustup (upstream requires Rust >= 1.80; stable is
   used by upstream CI).
2. Use the `node/22/stable` build snap and install pnpm 10 and
   `@tauri-apps/cli@2.11.5` into a writable local npm prefix.
3. Run `pnpm install --frozen-lockfile` and `pnpm build` in `ui/`.
4. Run `tauri build --no-bundle --config
   '{"build":{"beforeBuildCommand":""}}'` using the pinned npm CLI.
5. Install `target/release/limusic-app`, the desktop file, metainfo, and icons
   into `$CRAFT_PART_INSTALL`.

Tauri's `beforeBuildCommand` is disabled because the UI is built explicitly,
matching upstream CI's `--config '{"build":{"beforeBuildCommand":""}}'`.
`--no-bundle` avoids the Tauri bundler and its updater-signing requirements;
the Snap owns packaging.

`build-packages` lists `build-essential`, `pkg-config`, `curl`,
`ca-certificates`, `libmpv-dev`, `libssl-dev`, `libayatana-appindicator3-dev`
and `libdbus-1-dev`. The GNOME SDK
supplies the GTK 3 / WebKitGTK 4.1 / librsvg development files; if the first
build reports a missing header or `.pc` file, add only that specific noble
`-dev` package. The appindicator and dbus development packages mirror upstream
CI and are build-only: the released `v1.3.0` binary has no `DT_NEEDED` entry for
libayatana-appindicator, so the runtime library is not staged.

**Alternatives:** `tauri build --bundles deb` then extract the `.deb`
(rejected: extra bundler step, version/arch-dependent paths, and updater
artifact handling); plain `cargo build --release` (viable and equivalent, but
the pinned Tauri CLI keeps the build closer to upstream).

### 4. Ship a corrected desktop file and metainfo

Install `snap/local/limusic.desktop`, which mirrors upstream's entry but sets:

```
Exec=limusic
Icon=/usr/share/icons/hicolor/512x512/apps/limusic-app.png
StartupWMClass=limusic-app
```

`Exec` must be the snap app name (`limusic`), not the upstream binary name
(`limusic-app`): snapd's desktop export matches `Exec` against the app wrapper
(`/snap/bin/limusic`) and otherwise falls back to rewriting by desktop-file
basename. `StartupWMClass` stays `limusic-app` because that is the window class
Tauri sets. Snapcraft rewrites the absolute icon path to `${SNAP}/...` at prime
time. The snap also installs hicolor icons at 32, 64, 128, 256 and 512 pixels.
This is the same fix as PineconeMC's `sed` of `Icon=@Launcher_AppID@`, but
applied to a maintained local file rather than a generated one.

Install `snap/local/com.limusic.desktop.metainfo.xml` at
`usr/share/metainfo/com.limusic.desktop.metainfo.xml`. AppStream requires a
reverse-DNS component ID, so use `<id>com.limusic.desktop</id>` (the upstream
Tauri identifier) and `<launchable type="desktop-id">limusic.desktop</launchable>`.
`common-id: limusic` still matches the desktop basename. Upstream ships no
metainfo, so there is nothing to patch.

**Alternatives:** use Tauri's generated desktop file and `sed` `Icon=`
(rejected: requires the deb bundler and makes the path version-dependent);
reuse an upstream metainfo (none exists).

### 5. Disable the updater with a build-time patch

Upstream has no feature flag. The updater is registered unconditionally in
`src-tauri/src/lib.rs`, and the UI's `look()` in
`ui/src/lib/updater.svelte.ts` calls the plugin. Apply
`snap/local/disable-updater.patch` in `override-pull` with `git apply`. The
patch makes `look()` return `false`, so the quiet check, the Settings check and
the beta check do not offer an update. `canSelfUpdate()` already returns
`false` on Linux non-AppImage builds, but patching `look()` prevents even the
download-link banner.

The patch is applied only to `$CRAFT_PART_SRC`; the upstream repository is not
changed. No updater signing key is needed because `--no-bundle` produces no
updater artifacts.

**Alternatives:** remove the updater plugin from `lib.rs` (more invasive and
leaves UI calls failing); set `plugins.updater.endpoints` to `[]` (the UI falls
back to the releases API and still shows a banner); add an upstream feature flag
(out of scope and requires an upstream change).

### 6. Inject Last.fm credentials from a gitignored file

Upstream's `src-tauri/build.rs` reads `src-tauri/lastfm.keys` and emits
`LIMUSIC_LASTFM_API_KEY` / `LIMUSIC_LASTFM_API_SECRET` as compile-time
environment variables. `lastfm.rs` uses `option_env!`, so an absent file yields
empty strings and the UI reports "not configured".

Before Cargo runs, copy `$CRAFT_PROJECT_DIR/snap/local/lastfm.keys` to
`src-tauri/lastfm.keys` if it exists. Add `snap/local/lastfm.keys` to
`.gitignore` and provide `snap/local/lastfm.keys.example` with placeholders.
Snapcraft does not reliably forward arbitrary host environment variables into
an LXD build, so the local file is the documented mechanism. The build must
succeed without it.

**Alternatives:** put keys in `snapcraft.yaml` (forbidden); rely on host env
vars (unreliable across LXD/Multipass); commit a keys file (forbidden).

### 7. Interface selection

| Interface | Why |
| --- | --- |
| `network` | YouTube Music API, streams, Last.fm, sync server. |
| `network-bind` | Upstream runs a loopback HTTP proxy for music videos (`videoproxy.rs`); binding a localhost port needs this, not `network`. |
| `audio-playback` | libmpv audio output through PulseAudio/PipeWire. |
| `home` | Read local music in non-hidden home directories. |
| `removable-media` | Read local music on removable volumes; not auto-connected, documented. |
| `mpris` slot, `name: limusic` | Own `org.mpris.MediaPlayer2.limusic` for media keys and desktop widgets. |

The GNOME extension supplies `desktop` (StatusNotifierItem tray, notifications,
portals, GTK settings), `desktop-legacy`, `opengl`, `wayland`, `x11` and
`gsettings`, plus the `gnome-46-2404`, `gtk-3-themes`, `icon-themes` and
`sound-themes` content plugs and the `gpu-2404` content plug. No `unity7`,
`pulseaudio`, `personal-files` or appindicator interface is added.

The `mpris` slot's permanent policy allows binding the MPRIS name, and on a
classic Ubuntu host snapd adds the unconfined-client rules that let the desktop
shell control the player. The `desktop` interface's policy allows
StatusNotifierItem registration and notifications, but not arbitrary D-Bus
names or host autostart writes.

### 8. Document confinement limitations

- **Discord RPC:** `discord-rich-presence` connects to a Unix socket in the
  host `XDG_RUNTIME_DIR`. A strict snap has its own runtime directory and no
  interface grants access to the host's Discord IPC socket. The app fails soft;
  the README states RPC is unavailable in the Snap and suggests the deb/AppImage
  for users who need it.
- **Single instance:** `tauri-plugin-single-instance` tries to own
  `com.limusic.desktop.SingleInstance` on the session bus. Strict AppArmor does
  not grant that name, so the plugin logs a warning and the app launches
  normally. Set `LIMUSIC_MULTI=1` in the snap environment to skip the plugin
  and avoid the denial; document that two instances can then run.
- **Autostart:** `tauri-plugin-autostart` writes `~/.config/autostart`, which is
  the snap's private home, not the host's. The host desktop will not read it.
  Document that start-on-login is unsupported.
- **Global shortcuts:** X11 works through the `x11` interface; Wayland uses the
  desktop portal and may require user approval. Document as best-effort.
- **Video codecs:** the GNOME content snap has VP8/VP9/Opus/Matroska GStreamer
  plugins but no `libgstlibav`, so H.264/AAC-only video may not play. Audio
  playback is unaffected because it uses libmpv. Verify with a real music video.

### 9. Metadata and repository layout

```
snap/snapcraft.yaml
snap/local/limusic.desktop
snap/local/com.limusic.desktop.metainfo.xml
snap/local/disable-updater.patch
snap/local/lastfm.keys.example
snap/local/icon.png
.gitignore
README.md
```

`contact` and `issues` use `https://github.com/NetNexusOrg/limusic-snap`;
`source-code` uses the upstream repository; `website` uses
`https://limusic.app`. `license: GPL-3.0-only` matches the upstream GPL-3.0
license. The description explicitly says "unofficial community Snap" and
credits SimoHypers and the Limusic project.

## Risks / Trade-offs

- **Build size and time:** the Rust build pulls V8 through
  `rustypipe-botguard`; libmpv staging pulls FFmpeg and many codec libraries.
  Expect a long first build and a large snap. This is inherent to upstream.
- **GNOME SDK coverage:** the extension is expected to provide the GTK/WebKit
  development files. If the SDK lacks a header or `.pc` file, add the specific
  noble `-dev` package to `build-packages`; do not stage the corresponding
  runtime library.
- **Tauri CLI in the Node snap:** global npm installs may target a read-only
  prefix. Use `npm install --global --prefix "$CRAFT_PART_BUILD/.npm-global"`
  and prepend that `bin` directory to `PATH`.
- **Rust toolchain:** rustup downloads stable at build time. If the build
  environment cannot run the rustup installer, use the `rustup` build snap or
  the Snapcraft Rust plugin instead; the rest of the build is unchanged.
- **MPRIS slot review:** the `mpris` slot is a standard snapd interface; the
  `name: limusic` attribute must match upstream's `dbus_name`. If upstream
  changes the name, update both.
- **Updater patch drift:** the patch targets `v1.3.0` exactly. A future version
  bump must refresh the patch or replace it with an upstream-supported flag.
- **Last.fm credentials:** without the local keys file the build is valid but
  Last.fm is disabled. This is intentional and documented.
- **`snapcraft lint`:** expect warnings about staged libraries and possibly the
  desktop file. Fix relevant findings; document accepted ones.
