# 지화 실시간 학습 튜터 만들기

@Metadata {
    @TechnologyRoot
}

손으로 지문자를 만들면 어느 손가락이 몇 도 어긋났는지 짚어 주는 앱을, Vision Pro 없이 시뮬레이터에서 끝까지 따라 만듭니다.

**visionOS 튜토리얼 · 7단계 · visionOS 2.0+**

![27개 관절과 손바닥 법선을 보여 주는 손 특징 다이어그램](hand-feature-diagram.svg)

| 구성 | 설명 |
| --- | --- |
| 7단계 | 0~5는 시뮬레이터만으로 |
| 40자 | 자음 19 · 모음 21 |
| 22차원 | 굽힘 15 · 벌림 4 · 수향 3 |
| 1278줄 | Swift, 전문 수록 |

> Important: **이 튜토리얼의 규칙 세 가지**
>
> ① 모든 코드는 **실제로 빌드되는 프로젝트에서 복사**했습니다. 손으로 쓴 코드는 없습니다.
> ② 단계마다 **시뮬레이터에서 찍은 실제 화면**이 붙습니다. 그림이 아닙니다.
> ③ "여기는 알아서" 가 **한 번도 나오지 않습니다.** 빈칸이 있으면 그건 이 문서의 잘못입니다.

### 코드 블록 읽는 법

단계마다 나오는 코드 블록은 이렇게 읽습니다.

- **맨 위 `import` 줄부터 시작합니다.** 그 파일이 어떤 프레임워크를 쓰는지 첫 줄에서 바로 보입니다.
- **`// …` 는 중간을 건너뛴 자리입니다.** 그 파일의 다른 부분은 손대지 않습니다.
- **바탕이 칠해진 줄이 이번 단계에서 새로 넣거나 고치는 코드입니다.** 나머지는 이미 있는 코드이며, 어디에 넣어야 하는지 알려 주려고 함께 보여 줍니다.

```swift, highlight=[6, 7]
import SwiftUI

@main
struct JihwaTutorApp: App {

    // 바탕이 칠해진 이 줄이 이번 단계에서 새로 넣는 코드입니다.
    @State private var model = TutorModel()

    var body: some Scene {
        // …
    }
}
```

파일 하나의 처음부터 끝까지가 필요하면 <doc:Source-Files>에 19개 파일 전문이 있습니다. 복사해서 붙일 때는 그쪽이 편합니다.

> Warning: **먼저 알아 두어야 할 두 가지**
>
> **이 앱은 자기 손만 봅니다.** visionOS 손 추적은 헤드셋 착용자 본인의 손만 인식합니다. 앞사람의 수어를 읽거나 영상 속 손을 따라하는 것은 이 구조로 불가능합니다.
>
> **이 앱은 지화(지문자)만 다룹니다.** 지화는 한국수어에서 이름·외래어를 적을 때 쓰는 보조 수단입니다. 움직임이 있는 수어 단어는 시간축 모델이 따로 필요하며 여기서 다루지 않습니다.

## Topics

### 튜토리얼

- <doc:Step-0-Project-Setup>
- <doc:Step-1-Mock-Hand>
- <doc:Step-2-Pose-Features>
- <doc:Step-3-Reference-Poses>
- <doc:Step-4-Scoring-and-Coaching>
- <doc:Step-5-Expand-to-40-Characters>
- <doc:Step-6-Device-Tracking-and-Guide>

### 참고

- <doc:Limits-and-References>
- <doc:Source-Files>
