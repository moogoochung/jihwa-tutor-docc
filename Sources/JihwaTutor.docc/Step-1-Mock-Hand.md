# 1. 가짜 손부터 만든다

실기기가 없어도 끝까지 갈 수 있게, 진짜 손보다 가짜 손을 먼저 만듭니다.

## Overview

> Note: **이 단계에서 새로 만드는 파일** — `HandSample.swift` · `Jamo.swift` · `MockHandFeed.swift`. 세 파일 모두 `import ARKit`이 필요합니다. `HandAnchor.Chirality`(왼손/오른손 구분)가 ARKit에 있기 때문입니다. 시뮬레이터에서도 타입은 그대로 쓰입니다.

### 1.1

**왜 가짜 손이 먼저인가.** 시뮬레이터에는 손 스켈레톤 앵커가 오지 않습니다. 실기기를 전제로 만들면 Vision Pro가 없는 사람은 첫 화면도 못 봅니다. 그래서 데이터가 들어오는 *구멍*을 먼저 정의하고, 그 구멍에 가짜 데이터를 흘려 넣습니다.

**`HandSample.swift`** — 손 입력이 지켜야 할 약속

```swift, highlight=[6, 7, 8, 9, 10, 11]
import ARKit
import simd

// …

@MainActor
protocol HandFeed: AnyObject {
    var samples: AsyncStream<HandSample> { get }
    func start() async
    func stop()
}
```

### 1.2

한 프레임 분량의 손 정보를 `HandSample`로 정의합니다. 실기기 경로와 가짜 경로가 **같은 타입**을 내보내는 것이 핵심입니다. 나중에 진짜 손을 붙일 때 뒷단을 하나도 고치지 않아도 됩니다.

**`HandSample.swift`** — 한 프레임의 손

```swift, highlight=[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
import ARKit
import simd

/// 판정 단계로 넘어가는 한 프레임 분량의 손 정보.
/// 실기기 경로와 목 데이터 경로가 같은 타입을 낸다.
struct HandSample {
    var feature: PoseFeature
    var chirality: HandAnchor.Chirality
    /// 오버레이 정렬용. 목 데이터에서는 nil.
    var wristTransform: simd_float4x4?
    /// 손목에서 중지 너클까지의 거리. 오버레이 크기 보정에 쓴다.
    var handSpan: Float
    var timestamp: TimeInterval
}
```

### 1.3

먼저 다룰 자모 40자를 정의합니다. 한국수화사전(2005) 기준으로 자음 19자, 모음 21자입니다.

**`Jamo.swift`** — 자음 19 · 모음 21

```swift, highlight=[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
import Foundation

/// 한글 지문자 자모. 한국수화사전(2005) 기준 자음 19자 · 모음 21자 = 40자.
enum Jamo: String, CaseIterable, Identifiable, Sendable {
    // 자음 19
    case giyeok = "ㄱ", ssangGiyeok = "ㄲ", nieun = "ㄴ", digeut = "ㄷ", ssangDigeut = "ㄸ"
    case rieul = "ㄹ", mieum = "ㅁ", bieup = "ㅂ", ssangBieup = "ㅃ", siot = "ㅅ"
    case ssangSiot = "ㅆ", ieung = "ㅇ", jieut = "ㅈ", ssangJieut = "ㅉ", chieut = "ㅊ"
    case kieuk = "ㅋ", tieut = "ㅌ", pieup = "ㅍ", hieut = "ㅎ"

    // 모음 21
    case a = "ㅏ", ae = "ㅐ", ya = "ㅑ", yae = "ㅒ", eo = "ㅓ", e = "ㅔ", yeo = "ㅕ", ye = "ㅖ"
    case o = "ㅗ", wa = "ㅘ", wae = "ㅙ", oe = "ㅚ", yo = "ㅛ"
    case u = "ㅜ", weo = "ㅝ", we = "ㅞ", wi = "ㅟ", yu = "ㅠ"
    case eu = "ㅡ", ui = "ㅢ", i = "ㅣ"
    // …
}
```

### 1.4

가짜 손은 기준 포즈 주위에서 미세하게 떨리는 값을 90Hz로 내보냅니다. 중지 관절 하나에는 일부러 오차를 실어 둡니다. 나중에 채점이 이 오차를 잡아내는지 확인하는 데 씁니다.

**`MockHandFeed.swift`** — 떨리는 가짜 손 한 프레임

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
import ARKit
import Foundation
import QuartzCore
import simd

@MainActor
final class MockHandFeed: HandFeed {
    // …

    /// 중지 하나에 오차를 싣고, 나머지는 사람 손 떨림 수준으로만 흔든다.
    private func perturb(_ base: PoseFeature, phase: Float) -> HandSample {
        var bend = base.bend
        let jitter: Float = 0.02
        for i in bend.indices { bend[i] += sin(phase + Float(i)) * jitter }
        if bend.count > 6 { bend[7] += injectedError }   // 중지 중간 관절

        let f = PoseFeature(bend: bend, spread: base.spread, palmNormal: base.palmNormal)
        return HandSample(feature: f,
                          chirality: .right,
                          wristTransform: nil,
                          handSpan: 0.09,
                          timestamp: CACurrentMediaTime())
    }
}
```

### 1.5

**그 프레임을 90Hz로 흘려보냅니다.** `AsyncStream`에 계속 밀어 넣는 루프가 전부입니다. 굽힘각 15개가 화면에 흐르면 1단계 성공입니다 — 이 숫자가 이후 모든 계산의 원재료입니다.

**`MockHandFeed.swift`** — 90Hz 재생 루프

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
import ARKit
import Foundation
import QuartzCore
import simd

@MainActor
final class MockHandFeed: HandFeed {
    // …

    /// 프레임 주기. 90Hz.
    var interval: Duration = .milliseconds(11)

    func start() async {
        task = Task { [weak self] in
            var phase: Float = 0
            while !Task.isCancelled {
                guard let self else { return }
                if let base = ReferenceLibrary.shared.reference(for: self.target) {
                    self.continuation?.yield(self.perturb(base, phase: phase))
                }
                phase += 0.05
                try? await Task.sleep(for: self.interval)
            }
        }
    }
}
```

> Note: 값을 눈으로 보는 화면(`ErrorChart`)은 5단계에서 만듭니다. 지금은 `for await sample in feed.samples { print(sample.feature.bend) }` 한 줄이면 콘솔에서 숫자가 흐르는 것을 확인할 수 있습니다.

### 실행 결과

**1단계를 마치면 나오는 화면**

![1단계 실행 화면](step1.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 창에 bend[0]…bend[14] 값이 흐른다
- 손 크기와 좌우가 표시된다

#### 안 되면 확인할 것

- 숫자가 안 나오면 `.task { await feed.start() }`가 붙어 있는지 확인하세요.
- `MockHandFeed`는 `@MainActor`입니다. 다른 액터에서 부르면 컴파일 에러가 납니다.
- `Cannot find type 'HandAnchor' in scope` — `import ARKit`이 빠졌습니다. 세 파일 모두 필요합니다.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-2-Pose-Features>
