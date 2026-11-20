#!/usr/bin/env bash
#
# Move this packaging repository to a new upstream release tag.
#
#   scripts/bump-upstream.sh v1.5.0
#
# Updates the Snap version (always <upstream>-1), the pinned source tag, the
# user-facing file names and the AppStream release entry. Running it twice for
# the same tag is a no-op, so it is safe to call from CI.
set -euo pipefail

usage() {
  echo "usage: $0 vX.Y.Z" >&2
  exit 2
}

[ $# -eq 1 ] || usage
tag=$1
if [[ ! $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: '$tag' is not a stable vX.Y.Z tag" >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

current=$(sed -n 's/^[[:space:]]*source-tag:[[:space:]]*v\([0-9][0-9.]*\).*/\1/p' snap/snapcraft.yaml | head -n1)
if [ -z "$current" ]; then
  echo "error: could not read source-tag from snap/snapcraft.yaml" >&2
  exit 1
fi

base=${tag#v}
if [ "$current" = "$base" ]; then
  echo "Already on upstream $tag; nothing to do."
  exit 0
fi

# The packaging revision can be higher than -1 (for example 1.4.1-2 after a
# packaging-only fix), so read it from the recipe instead of assuming -1.
old_pkg=$(sed -n 's/^version:[[:space:]]*"\([^"]*\)"[[:space:]]*$/\1/p' snap/snapcraft.yaml | head -n1)
if [ -z "$old_pkg" ]; then
  old_pkg="${current}-1"
fi
new_pkg="${base}-1"
today=$(date -u +%F)

echo "Bumping upstream v$current -> $tag (packaging $old_pkg -> $new_pkg)"

sed -i \
  -e "s/^version: \"${old_pkg}\"$/version: \"${new_pkg}\"/" \
  -e "s/source-tag: v${current}\$/source-tag: ${tag}/" \
  -e "s/builds upstream v${current} /builds upstream ${tag} /" \
  snap/snapcraft.yaml

for f in README.md docs/packaging.md; do
  [ -f "$f" ] || continue
  sed -i \
    -e "s/${old_pkg}/${new_pkg}/g" \
    -e "s/v${current}/v${base}/g" \
    "$f"
done

python3 - "$base" "$today" <<'PY'
import pathlib
import sys

base, today = sys.argv[1], sys.argv[2]
path = pathlib.Path("snap/local/com.limusic.desktop.metainfo.xml")
text = path.read_text()
if f'version="{base}"' in text:
    print(f"metainfo: {base} already listed")
else:
    entry = f'    <release version="{base}" date="{today}"/>\n'
    text = text.replace("  <releases>\n", "  <releases>\n" + entry, 1)
    path.write_text(text)
    print(f"metainfo: added {base} ({today})")
PY

echo "Changed files:"
git diff --stat

if git diff --quiet; then
  echo "No changes were produced." >&2
  exit 1
fi
