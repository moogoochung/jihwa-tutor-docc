"""규칙 ① 검사 — 코드 블록에 나온 모든 줄이 그 파일의 실제 줄인지, 순서까지 맞는지 본다."""
import re, pathlib, sys
D = pathlib.Path(sys.argv[1]); SRC = D / "Resources" / "SourceCode"
ELISION = re.compile(r'^\s*//\s*…')
bad = 0
for f in sorted(D.glob("*.md")):
    if f.name in ("Source-Files.md",): continue
    lines = f.read_text().split("\n"); i = 0; current = None
    while i < len(lines):
        m = re.match(r'^\*\*`([\w+.]+)`\*\*', lines[i])
        if m: current = m.group(1)
        if not re.match(r'^```\w', lines[i]): i += 1; continue
        body, i = [], i + 1
        while i < len(lines) and lines[i].rstrip() != "```":
            body.append(lines[i]); i += 1
        i += 1
        if not current or not (SRC / current).exists(): continue
        src = (SRC / current).read_text().split("\n")
        cursor = 0
        for b in body:
            if b.strip() == "" or ELISION.match(b): continue
            try:
                cursor = src.index(b, cursor) + 1
            except ValueError:
                # 순서를 벗어났을 수도 있으니 파일 전체에서 한 번 더 찾는다
                if b in src:
                    bad += 1
                    print(f"⚠️  {f.name} · {current} · 순서 어긋남: {b.strip()[:70]}")
                    cursor = src.index(b) + 1
                else:
                    bad += 1
                    print(f"❌ {f.name} · {current} · 원본에 없는 줄: {b.strip()[:70]}")
print("규칙 ① 통과 — 모든 줄이 원본과 일치" if bad == 0 else f"{bad}건 확인 필요")
