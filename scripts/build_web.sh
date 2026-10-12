#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PACKAGE_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
if [[ ! "$PACKAGE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "Invalid package version: $PACKAGE_VERSION" >&2
  exit 1
fi
APP_VERSION="${PACKAGE_VERSION%%+*}"
"${FLUTTER_BIN:-flutter}" build web --release --no-pub \
  --dart-define="APP_VERSION=$APP_VERSION" "$@"
ARCHIVE="MoeTalk-web-v${APP_VERSION}.zip"
# Replace an earlier archive rather than retaining stale ZIP members.
rm -f "build/$ARCHIVE"
(cd build/web && zip -q -r "../$ARCHIVE" .)
echo "Built build/$ARCHIVE"
