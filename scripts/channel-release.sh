#!/usr/bin/env bash
#
# Print the release plan for one channel as GITHUB_OUTPUT lines.
#
#   scripts/channel-release.sh stable
#
# Prints `skip=true` when there is nothing new to publish. Otherwise prints
# `skip=false` plus the release tag, packaging version, the source kind (`tag`
# or `ref`) and the upstream ref to build. Human-readable messages go to stderr
# so the output stays parseable by the workflow.
#
# Requires GH_TOKEN (or a logged-in gh) and GITHUB_REPOSITORY. Set FORCE=true to
# rebuild a release that already exists.
set -euo pipefail

channel=${1:-}
case "$channel" in
  stable | candidate | beta | edge) ;;
  *)
    echo "usage: $0 <stable|candidate|beta|edge>" >&2
    exit 2
    ;;
esac

repo=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}
upstream=${UPSTREAM_REPO:-SimoHypers/limusic}
force=${FORCE:-false}

has_release() {
  gh release view "$1" --repo "$repo" >/dev/null 2>&1
}

# The stable channel keeps the packaging revision currently in the recipe, so a
# packaging-only fix reuses the source tag but still produces a new release
# (1.4.1-4, 1.4.1-5, ...). A new upstream base starts at -1.
recipe_version() {
  local base=$1 current
  current=$(gh api "repos/$repo/contents/snap/snapcraft.yaml" \
    -H "Accept: application/vnd.github.raw" \
    | sed -n 's/^version:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  if [[ -n $current && $current == "$base-"* ]]; then
    printf '%s\n' "$current"
  else
    printf '%s-1\n' "$base"
  fi
}

case "$channel" in
  stable)
    tag=$(gh api "repos/$upstream/releases/latest" --jq .tag_name)
    base=${tag#v}
    version=$(recipe_version "$base")
    kind=tag
    ref=$tag
    release_tag="v$version"
    ;;
  candidate)
    tag=$(gh api "repos/$upstream/releases?per_page=30" \
      --jq '[.[] | select(.prerelease)][0].tag_name // empty')
    if [[ -z $tag ]]; then
      echo "$channel: no upstream prerelease yet; nothing to do" >&2
      echo "skip=true"
      exit 0
    fi
    version="${tag#v}-1"
    kind=tag
    ref=$tag
    release_tag="v$version"
    ;;
  beta | edge)
    if [[ $channel == beta ]]; then
      branch=dev
      version_prefix=git-dev
    else
      branch=master
      version_prefix=git
    fi
    sha=$(gh api "repos/$upstream/commits/$branch" --jq .sha)
    short=${sha:0:7}
    version="$version_prefix-$short"
    kind=ref
    ref=$branch
    release_tag="$channel-$short"
    ;;
esac

if [[ $force != true ]] && has_release "$release_tag"; then
  echo "$channel: $release_tag already exists; nothing to do" >&2
  echo "skip=true"
  exit 0
fi

echo "$channel: will publish $release_tag from $ref" >&2
printf 'skip=false\nrelease_tag=%s\nversion=%s\nkind=%s\nref=%s\n' \
  "$release_tag" "$version" "$kind" "$ref"
