## Why

The Snap is currently built and validated by hand on one host. That makes
regressions easy to miss and ties releases to a machine with a working LXD
setup. A CI workflow gives every change to the packaging a reproducible build
and a lint result before it is merged or released.

## What Changes

- Add a GitHub Actions workflow that builds the Snap on `ubuntu-24.04` using
  LXD and Snapcraft.
- Build on pushes to `main`, tags matching `v*`, pull requests touching
  `snap/**` or the workflow, and manual dispatch.
- Inject Last.fm credentials from repository secrets when present, using the
  existing gitignored `snap/local/lastfm.keys` mechanism; build without them
  otherwise.
- Run `snapcraft lint`, generate a SHA-256 checksum, and upload the snap and
  checksum as workflow artifacts.
- Keep publishing to the Snap Store and creating GitHub Releases out of scope.

## Impact

- Affected specs: `snap-ci` (new capability).
- Affected code: `.github/workflows/build-snap.yml`.
- No runtime behavior or Snap metadata changes.
- No secrets are committed; CI only reads optional repository secrets.
