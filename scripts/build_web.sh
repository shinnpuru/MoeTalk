#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
  echo "Invalid package version: $APP_VERSION" >&2
  exit 1
fi
"${FLUTTER_BIN:-flutter}" build web --release --no-pub \
  --dart-define="APP_VERSION=$APP_VERSION" "$@"
ARCHIVE="MoeTalk-web-v${APP_VERSION}.zip"
# Replace an earlier archive rather than retaining stale ZIP members.
rm -f "build/$ARCHIVE"
(cd build/web && zip -q -r "../$ARCHIVE" .)
echo "Built build/$ARCHIVE"
