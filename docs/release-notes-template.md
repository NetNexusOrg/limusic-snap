# Limusic {{VERSION}} — unofficial Snap

This is an unofficial Snap package of [Limusic](https://github.com/SimoHypers/limusic),
a feature-rich desktop YouTube Music client built with Tauri, Rust and
SvelteKit. Limusic itself is developed by SimoHypers and licensed GPL-3.0.

This revision packages upstream **{{UPSTREAM_TAG}}**. Last.fm API credentials are
compiled into the binary at build time, so scrobbling works out of the box. No
credentials are stored in this repository.

## Install

```bash
curl -LO https://github.com/NetNexusOrg/limusic-snap/releases/download/v{{VERSION}}/limusic_{{VERSION}}_amd64.snap
curl -LO https://github.com/NetNexusOrg/limusic-snap/releases/download/v{{VERSION}}/limusic_{{VERSION}}_amd64.snap.sha256
sha256sum -c limusic_{{VERSION}}_amd64.snap.sha256
sudo snap install --dangerous ./limusic_{{VERSION}}_amd64.snap
```

SHA-256:

```text
{{SHA256}}
```

## What is included

- Upstream Limusic {{UPSTREAM_TAG}}.
- GTK 3 / WebKitGTK 4.1 through the GNOME extension.
- libmpv from Ubuntu 24.04, with the BLAS/LAPACK runtime symlinks that
  libsphinxbase needs.
- Last.fm API credentials compiled into the binary.
- MPRIS/media keys, tray, local music, audio playback and Google login.
- Strict confinement with only the documented interfaces.

## Updates

Updates are handled by snapd, not the Tauri updater. The Tauri updater is
disabled in this build.

## Known limitations

- **Discord Rich Presence** is unavailable under strict confinement because the
  host Discord IPC socket is not reachable. The app fails soft. Use the upstream
  deb/AppImage if you need RPC.
- **Start on login** is unsupported because a strict snap cannot write the
  host's `~/.config/autostart`.
- **Single instance** is disabled (`LIMUSIC_MULTI=1`); multiple instances can run.
- **Removable media** requires a one-time manual connection:
  `sudo snap connect limusic:removable-media`.
- **H.264/AAC-only video** may not play because the GNOME content snap does not
  include `libgstlibav`; audio is unaffected.
- **wallust / pywal** palettes cannot read host dotfiles; only the built-in and
  artwork-derived palettes work.

## Verification

- Built in GitHub Actions on Ubuntu 24.04 with LXD.
- `snapcraft lint` reports only accepted unused-library warnings from libmpv.
- Google login, audio, MPRIS, tray, local music and Last.fm were verified on the
  previous release; this revision changes the upstream version.

## Credits and license

Limusic is developed by SimoHypers:
https://github.com/SimoHypers/limusic

This unofficial packaging is maintained at:
https://github.com/NetNexusOrg/limusic-snap

Limusic and this package are licensed under GPL-3.0. See the `LICENSE` file in
the repository.
