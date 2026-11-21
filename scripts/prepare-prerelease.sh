#!/usr/bin/env bash
#
# Point the recipe at an upstream prerelease tag.
#
#   scripts/prepare-prerelease.sh v1.5.0-rc.1
#
# Used by CI for the candidate channel. Only the recipe changes: prereleases are
# not documented in the README and do not get an AppStream release entry.
set -euo pipefail

usage() {
  echo "usage: $0 vX.Y.Z-<prerelease>" >&2
  exit 2
}

[ $# -eq 1 ] || usage
tag=$1
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-.+$ ]]; then
  echo "error: '$tag' is not a vX.Y.Z-<prerelease> tag" >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

base=${tag#v}
version="${base}-1"

sed -i \
  -e "s/^version: \".*\"$/version: \"$version\"/" \
  -e "s/^\([[:space:]]*\)source-tag: .*$/\1source-tag: $tag/" \
  -e "s/builds upstream v[0-9][0-9.]* /builds upstream $tag /" \
  snap/snapcraft.yaml

grep -q "^version: \"$version\"$" snap/snapcraft.yaml \
  || { echo "error: version was not set" >&2; exit 1; }
grep -q "source-tag: $tag" snap/snapcraft.yaml \
  || { echo "error: source-tag was not set" >&2; exit 1; }

echo "Preparing the candidate $tag as $version"
git diff --stat
