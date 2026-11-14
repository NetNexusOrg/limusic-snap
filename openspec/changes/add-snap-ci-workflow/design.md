## Context

The Snap uses the GNOME extension, which is not compatible with
`snapcraft --destructive-mode`. The supported CI path is an LXD-backed build.
The upstream project needs unmodified network access during the Rust build
(crate downloads and the `lindera-ipadic` build script), so the runner must
provide working outbound networking to the LXD container.

## Goals

- Produce `limusic_<version>_amd64.snap` and its SHA-256 checksum on every
  relevant change.
- Keep the workflow independent of the maintainer's machine and local proxy
  workarounds.
- Make Last.fm credentials optional and never print or commit them.

## Decisions

### Use `canonical/setup-lxd@v1` and `snapcraft pack --use-lxd`

`canonical/setup-lxd@v1` installs and initializes LXD and handles the Docker
firewall interaction that otherwise blocks `lxdbr0`. Snapcraft is installed
from the stable snap channel, matching the local build that produced the
released snap. The build runs through `sg lxd` so the runner user has the LXD
socket group in the current shell.

### Optional Last.fm keys

The workflow writes `snap/local/lastfm.keys` only when both
`LASTFM_API_KEY` and `LASTFM_API_SECRET` repository secrets are set. The file
is already gitignored and read by `src-tauri/build.rs`. Without the secrets the
build succeeds and Last.fm reports "not configured", which is the documented
behavior.

### Artifacts, not releases

The workflow uploads the snap and checksum with `actions/upload-artifact@v4`.
Publishing to the Snap Store and creating GitHub Releases remain manual, so a
green CI run never publishes automatically.

## Risks

- LXD builds are slower than destructive builds; the job timeout is 45 minutes.
- CI cannot exercise the desktop session, audio, MPRIS, tray or portal login;
  those remain in the manual runtime checklist.
- A fork pull request cannot access repository secrets, so its artifact is
  built without Last.fm support by design.
- The workflow depends on the `canonical/setup-lxd` action and Snapcraft's
  stable channel; both can change independently of this repository.
