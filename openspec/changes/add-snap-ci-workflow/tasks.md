## 1. Workflow

- [x] 1.1 Add `.github/workflows/build-snap.yml` with `ubuntu-24.04`,
  checkout, `canonical/setup-lxd@v1`, Snapcraft stable and
  `snapcraft pack --use-lxd`.
- [x] 1.2 Add the optional Last.fm secret injection step; warn and continue
  when the secrets are absent.
- [x] 1.3 Add `snapcraft lint`, SHA-256 generation and
  `actions/upload-artifact@v4` for the snap and checksum.
- [x] 1.4 Configure triggers for `main`, `v*` tags, relevant pull requests and
  `workflow_dispatch`; set read-only permissions and a 45-minute timeout.

## 2. Documentation and verification

- [x] 2.1 Document the CI workflow, optional secrets and artifact location in
  the README.
- [x] 2.2 Validate the workflow syntax and the OpenSpec change.
- [x] 2.3 Mark task 6.4 in `package-limusic-snap` complete and commit the
  separate change.
