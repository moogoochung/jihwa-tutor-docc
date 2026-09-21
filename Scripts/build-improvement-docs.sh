#!/bin/bash
# Build the separate DocC improvement proposal without replacing the tutorial.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$REPO_ROOT/Sources/JihwaTutorRevision.docc"
SITE_ROOT="$REPO_ROOT/improvement"
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/jihwa-docc-improvement.XXXXXX")"
trap 'rm -rf "$BUILD_ROOT"' EXIT

xcrun docc convert "$CATALOG" \
  --output-path "$BUILD_ROOT/JihwaTutorRevision.doccarchive" \
  --transform-for-static-hosting \
  --hosting-base-path jihwa-tutor-docc/improvement \
  --warnings-as-errors

mkdir -p "$SITE_ROOT"
rsync -a --delete "$BUILD_ROOT/JihwaTutorRevision.doccarchive/" "$SITE_ROOT/"
cat > "$SITE_ROOT/index.html" <<'HTML'
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="0; url=./documentation/jihwatutorrevision/">
    <title>지화 튜터 문서 개선안</title>
    <script>
      const destination = new URL("documentation/jihwatutorrevision/", window.location.href);
      destination.search = window.location.search;
      destination.hash = window.location.hash;
      window.location.replace(destination.href);
    </script>
  </head>
  <body>
    <p><a href="./documentation/jihwatutorrevision/">지화 튜터 문서 개선안 열기</a></p>
  </body>
</html>
HTML
touch "$SITE_ROOT/.nojekyll"
echo "Built DocC proposal: $SITE_ROOT"
