#!/bin/bash
# Release a new Vibe Hero version end to end.
#
#   scripts/release.sh 0.1.2 [notes.md]
#
# Pipeline (the same steps that were done by hand for v0.1.0/v0.1.1):
#   1. bump CFBundleShortVersionString/CFBundleVersion in the Makefile
#   2. point the README's manual-download zip name at the new version
#   3. commit, push master, tag vX.Y.Z, push the tag
#   4. fetch the tag tarball from GitHub, compute its sha256
#   5. update the Homebrew tap formula (url + sha256), push the tap
#   6. make app, zip the bundle, create the GitHub Release with the zip
#
# notes.md is optional; without it the release gets a minimal note body.

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh X.Y.Z [notes.md]}"
NOTES_FILE="${2:-}"
TAG="v$VERSION"
REPO="tsonglew/VibeHero"
TAP_DIR="${TAP_DIR:-$(brew --repository)/Library/Taps/tsonglew/homebrew-tap}"

echo "==> preflight"
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean"; exit 1; }
[ "$(git branch --show-current)" = "master" ] || { echo "not on master"; exit 1; }
[ -f "$TAP_DIR/Formula/vibe-hero.rb" ] || { echo "tap not found at $TAP_DIR"; exit 1; }
git fetch -q origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] || { echo "master not in sync with origin"; exit 1; }
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "$TAG already exists"; exit 1; }

echo "==> bump version to $VERSION"
sed -i '' "/CFBundleShortVersionString/{n;s|<string>[^<]*</string>|<string>$VERSION</string>|;}" Makefile
# CFBundleVersion lives in the Makefile template; bump the integer there.
CURRENT_BUILD=$(grep -A1 'CFBundleVersion' Makefile | grep -o '[0-9]\+' | head -1)
sed -i '' "/CFBundleVersion/{n;s|<string>[0-9]*</string>|<string>$((CURRENT_BUILD + 1))</string>|;}" Makefile
sed -i '' "s/Vibe-Hero-v[0-9]*\.[0-9]*\.[0-9]*\.zip/Vibe-Hero-v$VERSION.zip/g" README.md

git add Makefile README.md
git commit -q -m "Release $TAG"
git push -q origin master

echo "==> tag $TAG"
git tag -a "$TAG" -m "Vibe Hero $TAG"
git push -q origin "$TAG"

echo "==> tag tarball sha256"
TARBALL="/tmp/vibe-hero-$TAG.tar.gz"
SHA=""
for _ in $(seq 1 10); do
  if curl -sfL --max-time 60 "https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz" -o "$TARBALL"; then
    SHA=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
    [ -n "$SHA" ] && break
  fi
  echo "  archive not ready, retrying in 5s"
  sleep 5
done
[ -n "$SHA" ] || { echo "could not fetch tag tarball"; exit 1; }
echo "  $SHA"

echo "==> update tap formula"
sed -i '' \
  -e "s|archive/refs/tags/v[^/]*\.tar\.gz|archive/refs/tags/$TAG.tar.gz|" \
  -e "s|^  sha256 \".*\"|  sha256 \"$SHA\"|" \
  "$TAP_DIR/Formula/vibe-hero.rb"
git -C "$TAP_DIR" commit -q -am "vibe-hero $VERSION"
git -C "$TAP_DIR" push -q origin main

echo "==> build and zip the bundle"
make app
ZIP=".build/app/Vibe-Hero-v$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent ".build/app/Vibe Hero.app" "$ZIP"
ZIP_SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')

echo "==> create GitHub Release"
if [ -n "$NOTES_FILE" ]; then
  gh release create "$TAG" "$ZIP" -R "$REPO" --title "Vibe Hero $VERSION" --notes-file "$NOTES_FILE"
else
  gh release create "$TAG" "$ZIP" -R "$REPO" --title "Vibe Hero $VERSION" \
    --notes "See the [README](https://github.com/$REPO#readme) for install (Homebrew tap or manual zip). SHA-256 of the zip: \`$ZIP_SHA\`"
fi

echo "==> done: $(gh release view "$TAG" -R "$REPO" --json url --jq .url)"
