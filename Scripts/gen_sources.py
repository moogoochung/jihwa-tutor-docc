#!/usr/bin/env python3
"""Resources/SourceCode 의 파일들로 Source-Files.md 를 다시 만든다."""
import pathlib, sys

DOCC = pathlib.Path(sys.argv[1])
SRC = DOCC / "Resources" / "SourceCode"

ORDER = [
    "JihwaTutorApp.swift", "Info.plist", "Jamo.swift", "PoseFeature.swift",
    "PoseFeature+Angles.swift", "PoseMatcher.swift", "Stabilizer.swift", "Coaching.swift",
    "ReferenceLibrary.swift", "HandSample.swift", "HandTrackingFeed.swift", "MockHandFeed.swift",
    "GuideOverlay.swift", "ErrorChart.swift", "PracticeSpace.swift", "TutorModel.swift",
    "TutorView.swift", "JamoPicker.swift", "VerdictCard.swift",
]

missing = [n for n in ORDER if not (SRC / n).exists()]
extra = sorted(p.name for p in SRC.iterdir() if p.is_file() and p.name not in ORDER)
if missing or extra:
    raise SystemExit(f"파일 목록 불일치 — 없음: {missing} / 목록에 없는 파일: {extra}")

def nlines(n): return len((SRC / n).read_text().rstrip("\n").split("\n"))
swift_total = sum(nlines(n) for n in ORDER if n.endswith(".swift"))
total = sum(nlines(n) for n in ORDER)

parts = [
    "# 전체 소스 파일",
    "",
    f"19개 파일 전문을 그대로 수록합니다. Swift 18개 파일 {swift_total}행에 `Info.plist`를 더해 모두 {total}행입니다. "
    "단계별 페이지에는 그 단계에서 다루는 부분만 잘라 보여 주므로, "
    "**복사해서 붙일 때는 이 페이지를 쓰세요.**",
    "",
    "> Warning: `ReferenceLibrary.swift`의 기준 포즈 값은 자리표시자입니다. "
    "실제 판정에 사용하기 전에 공식 자료와 실측 데이터로 교체하세요.",
    "",
    "## Overview",
    "",
    "### 파일 목록",
    "",
]
for n in ORDER:
    lines = nlines(n)
    parts.append(f"- `{n}` — {lines}행")
parts.append("")

for n in ORDER:
    lang = "xml" if n.endswith(".plist") else "swift"
    body = (SRC / n).read_text().rstrip("\n")
    parts += [f"### {n}", "", f"```{lang}", body, "```", ""]

parts += ["### 계속하기", "", "- <doc:JihwaTutor>", "- <doc:Limits-and-References>", ""]
(DOCC / "Source-Files.md").write_text("\n".join(parts))
print(f"Source-Files.md 재생성 — 19개 파일 · Swift {swift_total}행 · 합계 {total}행")
