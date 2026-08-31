#!/bin/bash
# JihwaTutor DocC 사이트 빌드.
#
#   ./Scripts/build-docs.sh          Sources/JihwaTutor.docc 를 빌드해 저장소 루트에 넣는다
#   ./Scripts/build-docs.sh --check  빌드하지 않고 검사만 한다
#
# Xcode 프로젝트 위치는 XCODE_SOURCES 로 덮어쓸 수 있다. 없으면 동기화 단계만 건너뛴다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCC="$ROOT/Sources/JihwaTutor.docc"

XCODE_SOURCES="${XCODE_SOURCES:-/Users/moogoochung/Documents/Codex/2026-08-25/https-erinkyb-github-io-2026techmap-tutorial/outputs/JihwaTutor/JihwaTutor/Sources}"

# 이 플래그가 없으면 ```swift, highlight=[...] 가 통째로 언어 이름이 되어
# 줄 강조는 물론 Swift 문법 색까지 전부 사라진다. 오류도 경고도 나지 않는다.
FLAGS=(--enable-experimental-code-block-annotations)

echo "▸ Xcode 프로젝트 소스를 DocC 리소스로 동기화"
if [ -d "$XCODE_SOURCES" ]; then
  cp "$XCODE_SOURCES"/*.swift "$DOCC/Resources/SourceCode/"
else
  echo "  건너뜀 — $XCODE_SOURCES 없음"
fi

echo "▸ Source-Files.md 재생성"
python3 "$ROOT/Scripts/gen_sources.py" "$DOCC"

echo "▸ 규칙 ① 검사 — 코드 블록이 실제 소스와 같은지"
python3 "$ROOT/Scripts/fidelity.py" "$DOCC"

echo "▸ 강조 줄 번호 범위 검사"
if python3 "$ROOT/Scripts/review.py" "$DOCC" | grep -q "⚠️"; then
  echo "  강조 줄 번호가 블록 범위를 벗어났습니다."; exit 1
fi

if [ "${1:-}" = "--check" ]; then echo "검사만 하고 끝냅니다."; exit 0; fi

echo "▸ docc convert"
ARCHIVE="$(mktemp -d)/JihwaTutor.doccarchive"
xcrun docc convert "$DOCC" \
  --output-path "$ARCHIVE" \
  --transform-for-static-hosting \
  --hosting-base-path jihwa-tutor-docc \
  "${FLAGS[@]}"

echo "▸ 저장소 루트에 반영"
for d in css data documentation images img index js downloads videos; do
  rm -rf "${ROOT:?}/$d"
done
rm -f "$ROOT"/{developer-og-twitter.jpg,developer-og.jpg,favicon.ico,favicon.svg,index.html,metadata.json}
cp -R "$ARCHIVE"/* "$ROOT/"
rm -rf "$(dirname "$ARCHIVE")"

# docc 가 만드는 index.html 은 문서 루트로 보내 주지 않는다.
# 저장소 주소를 열었을 때 문서로 넘어가도록 직접 만든 것으로 되돌린다.
echo "▸ 루트 리다이렉트 index.html 다시 쓰기"
cat > "$ROOT/index.html" <<'HTML'
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="0; url=./documentation/jihwatutor/">
    <title>지화 튜터 문서로 이동 중…</title>
    <script>
      const destination = new URL("documentation/jihwatutor/", window.location.href);
      destination.search = window.location.search;
      destination.hash = window.location.hash;
      window.location.replace(destination.href);
    </script>
  </head>
  <body>
    <p><a href="./documentation/jihwatutor/">지화 튜터 문서 열기</a></p>
  </body>
</html>
HTML

touch "$ROOT/.nojekyll"
echo "▸ 끝. git diff 로 확인한 뒤 커밋하세요."
