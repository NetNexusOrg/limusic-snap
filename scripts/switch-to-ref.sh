#!/usr/bin/env bash
#
# Point the recipe at an upstream branch head instead of a release tag.
#
#   scripts/switch-to-ref.sh dev
#
# Used by CI for the beta (dev) and edge (master) channels. The version becomes
# git-<sha> for master and git-<branch>-<sha> otherwise, the pinned source-tag
# becomes source-commit so the build is reproducible, and the grade drops to
# devel because the result is not a release candidate.
set -euo pipefail

usage() {
  echo "usage: $0 <branch>" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ref=$1
if [[ ! "$ref" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "error: '$ref' is not a valid branch name" >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

sha=$(git ls-remote https://github.com/SimoHypers/limusic.git "refs/heads/$ref" \
  | cut -f1 | head -n1)
if [ -z "$sha" ]; then
  echo "error: branch '$ref' not found upstream" >&2
  exit 1
fi

short=${sha:0:7}
if [ "$ref" = "master" ]; then
  version="git-$short"
else
  version="git-$ref-$short"
fi

sed -i \
  -e "s/^version: \".*\"$/version: \"$version\"/" \
  -e "s/^\([[:space:]]*\)source-tag: .*$/\1source-commit: $sha/" \
  -e "s/^grade: stable$/grade: devel/" \
  snap/snapcraft.yaml

grep -q "^version: \"$version\"$" snap/snapcraft.yaml \
  || { echo "error: version was not set" >&2; exit 1; }
grep -q "source-commit: $sha" snap/snapcraft.yaml \
  || { echo "error: source-commit was not set" >&2; exit 1; }

echo "Building upstream $ref at $sha as $version"
git diff --stat
