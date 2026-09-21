# JihwaTutor DocC

visionOS 튜토리얼 **지화 실시간 학습 튜터 만들기** 의 원본과 빌드 결과물입니다.

- 문서: <https://moogoochung.github.io/jihwa-tutor-docc/>
- 문서 개선안: <https://moogoochung.github.io/jihwa-tutor-docc/improvement/>
- 호스팅 기준 경로는 저장소 이름과 같은 `jihwa-tutor-docc` 로 맞춰져 있습니다.

## 문서 개선안 DocC

`Sources/JihwaTutorRevision.docc/`는 소개문·0~6단계 개정안·구현 및 검증 기준을 담은 별도 DocC 카탈로그입니다.
앱의 구현 완료 보고서가 아니라 문서와 코드의 개선 제안이며, 기존 튜토리얼과 별도 경로에서 제공합니다.

```bash
./Scripts/build-improvement-docs.sh
```

빌드 결과는 `improvement/`에 저장됩니다. 이 스크립트는 기존 튜토리얼 소스나 루트 사이트를 덮어쓰지 않습니다.
원본과 빌드 결과를 함께 커밋하면 기존 Pages 워크플로가 `/jihwa-tutor-docc/improvement/`에 배포합니다.
정적 호스팅 기준 경로는 `jihwa-tutor-docc/improvement`입니다.

## 구성

| 경로 | 내용 |
| --- | --- |
| `Sources/JihwaTutor.docc/` | **문서 원본.** 고칠 때는 여기를 고칩니다 |
| `Sources/JihwaTutor.docc/Resources/SourceCode/` | 문서에 싣는 Swift 19개 파일. Xcode 프로젝트에서 복사해 온 것 |
| `Scripts/build-docs.sh` | 동기화 → 검사 → 빌드 → 루트 반영까지 한 번에 |
| `Scripts/gen_sources.py` | `Source-Files.md` 를 실제 소스로 다시 만든다 |
| `Scripts/fidelity.py` | 규칙 ① 검사 — 코드 블록의 모든 줄이 실제 소스와 같은지 |
| `Scripts/review.py` | 강조 줄 번호가 블록 범위 안에 있는지 |
| 나머지 루트 파일 | `docc convert` 가 만든 정적 사이트. **직접 고치지 마세요** |

## 고치는 순서

```bash
./Scripts/build-docs.sh
```

1. **코드를 고칠 때는 Xcode 프로젝트를 먼저 고치고 빌드해 통과시킵니다.**
   문서에만 코드를 적으면 규칙 ①("모든 코드는 실제로 빌드되는 프로젝트에서 복사")이 깨집니다.
   프로젝트 위치가 다르면 `XCODE_SOURCES=... ./Scripts/build-docs.sh` 로 알려 주세요.
2. `Sources/JihwaTutor.docc/` 의 Markdown을 고칩니다.
3. `./Scripts/build-docs.sh` — 소스를 동기화하고, `Source-Files.md` 를 다시 만들고,
   검사한 뒤 저장소 루트의 정적 사이트를 갱신합니다.
4. `git diff` 로 확인하고 커밋 · 푸시합니다. GitHub Actions가 배포합니다.

빌드 없이 검사만 하려면 `./Scripts/build-docs.sh --check`.

## 코드 블록에 강조 넣기

DocC 의 실험적 기능입니다. 펜스에 `highlight=` 를 붙이면 그 줄만 배경이 칠해집니다.

````markdown
```swift, highlight=[6, 7]
import SwiftUI

@main
struct JihwaTutorApp: App {

    @State private var model = TutorModel()
    var body: some Scene { /* … */ }
}
```
````

- 줄 번호는 **블록 안에서 1부터** 셉니다. 원본 파일의 줄 번호가 아닙니다.
- 범위 문법(`2-4`, `2...4`)은 지원하지 않습니다. `[2, 3, 4]` 처럼 낱개로 적습니다.
- `showLineNumbers` · `nocopy` · `wrap` · `strikeout=N` 도 같은 자리에 쓸 수 있습니다.

> **`--enable-experimental-code-block-annotations` 플래그가 없으면 조용히 망가집니다.**
> `swift, highlight=[6, 7]` 전체가 언어 이름으로 잡혀 Swift 문법 색까지 사라집니다.
> 오류도 경고도 나지 않으니 반드시 `build-docs.sh` 로 빌드하세요.

## 문서 규칙

- 코드 블록은 **`import` 줄부터** 시작합니다. 어떤 프레임워크가 필요한지 첫 줄에서 보이도록.
- 중간을 건너뛴 자리는 `// …` 로 표시합니다.
- 그 단계에서 새로 넣거나 고치는 줄만 강조합니다.
- 파일 전체가 새 코드인 블록은 강조하지 않습니다. 전부 칠하면 강조가 아니게 됩니다.

## 배포

**Settings → Pages → Build and deployment → Source** 가 **GitHub Actions** 로 되어 있어야 합니다.
`main` 에 푸시하면 `.github/workflows/pages.yml` 이 저장소 내용을 그대로 배포합니다.
루트 주소를 열면 `index.html` 이 `/documentation/jihwatutor/` 로 보냅니다 —
이 파일은 `docc` 가 만드는 것을 덮어쓴 것이며, `build-docs.sh` 가 매번 다시 씁니다.

> 저장소 이름을 바꾸면 DocC 자산 경로도 달라집니다.
> `build-docs.sh` 의 `--hosting-base-path` 값을 새 이름으로 바꾸어 다시 빌드하세요.
