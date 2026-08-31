# 지화 실시간 학습 튜터 만들기

@Metadata {
    @TechnologyRoot
}

손으로 지문자를 만들면 어느 손가락이 몇 도 어긋났는지 짚어 주는 앱을, Vision Pro 없이 시뮬레이터에서 끝까지 따라 만듭니다.

## Overview

@Row {
    @Column {
        ## 3시간 50분
        **예상 소요 시간**

        @Small {
            실기기 없이 0~5단계까지만 하면 **3시간 20분**
        }
    }
    @Column {
        ## 7단계
        **자모 40자 · Swift 1278행**

        @Small {
            0~5단계는 시뮬레이터만으로 끝납니다
        }
    }
    @Column {
        ## Xcode 26
        **visionOS 2.0+**

        @Small {
            6단계만 Apple Vision Pro 실기기가 필요합니다
        }
    }
}

![27개 관절과 손바닥 법선을 보여 주는 손 특징 다이어그램](hand-feature-diagram.svg)

### 단계별 예상 소요 시간

코드를 직접 따라 치면서 설명을 읽는 기준입니다. 복사해서 붙이면 더 빠릅니다.

| 단계 | 시간 | 하는 일 |
| --- | --- | --- |
| <doc:Step-0-Project-Setup> | 25분 | Xcode에서 visionOS 프로젝트를 만들고 빈 창을 띄웁니다 |
| <doc:Step-1-Mock-Hand> | 25분 | 시뮬레이터에서 쓸 가짜 손과 자모 40자를 정의합니다 |
| <doc:Step-2-Pose-Features> | 35분 | 관절 27개를 22개의 숫자로 줄입니다. 이 단계에 수학이 몰려 있습니다 |
| <doc:Step-3-Reference-Poses> | 30분 | 정답 포즈를 기록하고 평균·표준편차를 냅니다 |
| <doc:Step-4-Scoring-and-Coaching> | 45분 | 채점하고 교정 문장을 만듭니다. 가장 긴 단계입니다 |
| <doc:Step-5-Expand-to-40-Characters> | 40분 | 40자로 늘리고 화면을 조립합니다 |
| <doc:Step-6-Device-Tracking-and-Guide> | 30분 | 실기기의 진짜 손과 3D 가이드를 붙입니다 |

> Tip: 한 번에 다 하지 않아도 됩니다. **0~2단계**(1시간 25분)까지 하면 손이 22개의 숫자로 바뀌는 것까지 보이고, **0~4단계**(2시간 40분)까지 하면 채점과 교정 문장이 돌아갑니다. 둘 다 끊어 가기 좋은 자리입니다.

### 시작하기 전에 알아 두면 좋은 것

모르는 것이 있어도 시작할 수는 있습니다. 다만 아래를 알고 있으면 막히는 자리가 크게 줄어듭니다.

| 알아 두면 좋은 것 | 어느 정도면 충분한가 | 모르면 어디서 막히나 |
| --- | --- | --- |
| **Swift 문법** | 구조체 · 열거형 · 프로토콜 · 옵셔널 · 클로저를 읽을 수 있으면 됩니다 | 전 단계 |
| **SwiftUI 기본** | `View`를 만들고 `@State`로 값을 바꿔 화면을 갱신해 본 경험 | 5단계 화면 조립 |
| **`async`/`await`** | `await`가 붙은 함수를 불러 본 정도. `AsyncStream`은 여기서 설명합니다 | 1단계 손 입력, 4단계 루프 |
| **벡터 연산** | 내적·외적이 *무엇을 재는 것인지*만. 손으로 계산할 필요는 없습니다 | 2단계 굽힘각·법선 |
| **Xcode** | 프로젝트를 만들고 시뮬레이터에서 실행해 본 경험 | 0단계 |

**몰라도 됩니다.** 이 튜토리얼이 필요한 만큼 그때그때 설명합니다.

- **visionOS · ARKit · RealityKit 경험** — 손 추적도, 몰입 공간도, 3D 오버레이도 처음이라고 보고 씁니다.
- **한국수어나 지화 지식** — 다만 만들고 나서 표준 손 모양은 <doc:Limits-and-References>의 공식 자료로 반드시 확인해야 합니다.
- **Apple Vision Pro 실기기** — 0~5단계는 시뮬레이터만으로 끝납니다. 6단계에서만 필요합니다.
- **머신러닝** — 이 앱은 모델을 학습시키지 않습니다. 전부 기하 계산입니다.

> Tip: Swift와 SwiftUI가 처음이라면 [Develop in Swift Tutorials](https://developer.apple.com/tutorials/develop-in-swift)를 먼저 보고 오세요. 여기서 쓰는 문법은 그 튜토리얼 범위를 벗어나지 않습니다.

### 준비물

| 준비물 | 비고 |
| --- | --- |
| **Xcode 26** 이상 | visionOS 플랫폼 지원을 함께 내려받아야 합니다 (Settings ▸ Components, 3~4GB) |
| **Apple Vision Pro 시뮬레이터** | Xcode에 포함. 0~5단계는 이것만 있으면 됩니다 |
| **Apple Vision Pro 실기기** | 6단계에서만. 개발자 모드를 켜야 합니다 |
| **전체 소스** | <doc:Source-Files>에 19개 파일 전문이 있습니다. 복사해서 붙일 때 씁니다 |

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
