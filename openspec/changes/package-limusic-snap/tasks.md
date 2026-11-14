# Tasks

## 0. Planning and validation

- [x] 0.1 Review `proposal.md`, `design.md`, and both specs; confirm upstream
  `v1.3.0`, the `NetNexusOrg/limusic-snap` contact URL, and the documented
  strict-confinement limitations.
- [x] 0.2 Confirm the GNOME extension + staged `libmpv2` approach and the
  `network-bind` requirement for the loopback video proxy.

## 1. Repository scaffold

- [x] 1.1 Add `.gitignore` for `parts/`, `stage/`, `prime/`, `*.snap`,
  `.snapcraft/`, `snap/local/lastfm.keys`, build logs, and editor/OS noise.
- [x] 1.2 Create `snap/local/` and add the desktop file, metainfo, updater
  patch, Last.fm example file, and store icon.
- [x] 1.3 Add a short `README.md` with build/install commands, the test
  checklist, credits, and the strict-confinement limitations.

## 2. Snap recipe

- [x] 2.1 Write `snap/snapcraft.yaml` with `name: limusic`, `base: core24`,
  `grade: stable`, `confinement: strict`, `platforms: amd64`, `version: "1.3.0"`,
  `source-tag: v1.3.0`, and `apps.limusic.extensions: [gnome]`.
- [x] 2.2 Add complete metadata: title, summary, unofficial/credit description,
  `license: GPL-3.0-only`, website, source-code, contact, issues, icon,
  `common-id: limusic`, and `desktop: usr/share/applications/limusic.desktop`.
- [x] 2.3 Declare the app command `bin/limusic-app`, the five explicit plugs
  (`network`, `network-bind`, `audio-playback`, `home`, `removable-media`), the
  `mpris` slot with `name: limusic`, and `LIMUSIC_MULTI=1`.
- [x] 2.4 Add the `limusic` part with the upstream Git source, `build-snaps:
  [node/22/stable]`, and build packages (`build-essential`, `pkg-config`,
  `curl`, `ca-certificates`, `libmpv-dev`, `libssl-dev`,
  `libayatana-appindicator3-dev`, `libdbus-1-dev`, plus any SDK
  gap found during the first build).
- [x] 2.5 Add `stage-packages` (`libmpv2`, plus `libblas3` and `liblapack3` for
  `libsphinxbase3`'s soname dependencies) and verify Snapcraft resolves the
  runtime dependencies; do not stage WebKit, GTK, GStreamer or appindicator.
  Create the BLAS/LAPACK top-level soname symlinks in `override-build` because
  Snapcraft does not run `update-alternatives`.

## 3. Build logic

- [x] 3.1 In `override-pull`, run `craftctl default` and apply
  `snap/local/disable-updater.patch` with `git apply`.
- [x] 3.2 In `override-build`, install stable Rust with rustup, install pnpm 10
  and `@tauri-apps/cli@2.11.5` into a writable local npm prefix, and prepend it
  to `PATH`.
- [x] 3.3 Copy `snap/local/lastfm.keys` to `src-tauri/lastfm.keys` when present;
  otherwise continue without it.
- [x] 3.4 Run `pnpm install --frozen-lockfile` and `pnpm build` in `ui/`, then
  `tauri build --no-bundle --config
  '{"build":{"beforeBuildCommand":""}}'`.
- [x] 3.5 Install `target/release/limusic-app` to `bin/limusic-app`, the desktop
  file to `usr/share/applications/`, the metainfo to `usr/share/metainfo/`, and
  the 32/64/128/256/512 hicolor icons to
  `usr/share/icons/hicolor/<size>/apps/limusic-app.png`.

## 4. Auxiliary files

- [x] 4.1 Write `snap/local/limusic.desktop` mirroring upstream's entry with
  `Exec=limusic` (the snap app command, not the `limusic-app` binary),
  `Icon=/usr/share/icons/hicolor/512x512/apps/limusic-app.png`, and
  `StartupWMClass=limusic-app`.
- [x] 4.2 Write `snap/local/com.limusic.desktop.metainfo.xml` with
  `<id>com.limusic.desktop</id>`, a launchable referencing `limusic.desktop`,
  upstream URLs, GPL-3.0-only, screenshots, and a release entry for 1.3.0.
- [x] 4.3 Write `snap/local/disable-updater.patch` that makes `look()` in
  `ui/src/lib/updater.svelte.ts` return `false` for the Snap build.
- [x] 4.4 Write `snap/local/lastfm.keys.example` with the two placeholder lines
  and no real values; document the format in the README.
- [x] 4.5 Add `snap/local/icon.png` (512x512) from the upstream icon set.

## 5. Build and verify

- [x] 5.1 Run `snapcraft pack` in LXD or Multipass; confirm the snap is
  produced without build errors.
- [x] 5.2 Install with `sudo snap install --dangerous ./limusic_1.3.0_amd64.snap`.
- [x] 5.3 Verify the app opens, the login webview loads, and audio playback
  starts (libmpv + `audio-playback`).
- [x] 5.4 Verify media keys/MPRIS through
  `org.mpris.MediaPlayer2.limusic` and the desktop media widget.
- [x] 5.5 Verify the tray icon and its menu on a desktop with a
  StatusNotifierWatcher.
- [ ] 5.6 Verify local music from a non-hidden home directory and from a
  connected removable volume. Home library verified (170 tracks imported);
  removable-volume path still needs a physical device and manual
  `removable-media` connection.
- [x] 5.7 Verify Discord RPC fails soft (expected: no Rich Presence) and record
  the log message.
- [x] 5.8 Run `snap connections limusic` and confirm only the documented
  interfaces are connected; connect `removable-media` manually if needed.
- [x] 5.9 Run `snappy-debug` while exercising the app, review AppArmor denials,
  and adjust only if a documented feature is blocked.
- [x] 5.10 Run `snapcraft lint` and fix relevant warnings; record accepted
  findings.

## 6. Documentation and follow-ups

- [x] 6.1 Finish `README.md`: prerequisites, build with LXD/Multipass, local
  install, Last.fm keys, limitations, credits, and links.
- [x] 6.2 Document that updates come from snapd and that the Tauri updater is
  disabled in the Snap.
- [x] 6.3 Document the Snap Store follow-up separately: register the `limusic`
  name, publish to `edge`, test, then promote to `stable`.
- [x] 6.4 Add a separate GitHub Actions workflow change for CI builds; do not
  mix it into this packaging change. Implemented in
  `openspec/changes/add-snap-ci-workflow`.
