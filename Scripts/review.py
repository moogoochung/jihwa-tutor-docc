import re, pathlib, sys
D = pathlib.Path(sys.argv[1])
for f in sorted(D.glob("*.md")):
    if f.name == "Source-Files.md": continue
    lines = f.read_text().split("\n"); i = 0
    print("="*70); print(f.name)
    while i < len(lines):
        m = re.match(r'^```(\w+)(?:,\s*highlight=\[([\d,\s]*)\])?\s*$', lines[i])
        if not m: i += 1; continue
        hl = set(int(x) for x in m.group(2).split(",")) if m.group(2) else set()
        body, i = [], i+1
        while i < len(lines) and lines[i].rstrip() != "```":
            body.append(lines[i]); i += 1
        i += 1
        bad = [n for n in hl if n < 1 or n > len(body)]
        print(f"\n--- {m.group(1)} · {len(body)}줄 · 강조 {len(hl)}줄" + (f"  ⚠️ 범위 밖: {bad}" if bad else ""))
        for n, b in enumerate(body, 1):
            print(("▶ " if n in hl else "  ") + b[:96])
