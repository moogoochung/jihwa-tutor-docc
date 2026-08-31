# 4. 채점하고 문장을 만든다

틀렸다는 사실이 아니라, 무엇을 어떻게 바꿔야 하는지를 말합니다. 이 앱이 인식기가 아니라 튜터인 이유입니다.

## Overview

> Note: **이 단계에서 새로 만드는 파일** — `PoseMatcher.swift`(`Foundation` · `simd`) · `Coaching.swift`(`Foundation`) · `Stabilizer.swift`(`Foundation`) · `TutorModel.swift`(`ARKit` · `Observation` · `SwiftUI`). 판정 쪽 세 파일은 손 추적을 만지지 않으므로 ARKit이 필요 없습니다. `TutorModel`만 `HandAnchor.Chirality`를 쓰기 때문에 ARKit이 필요합니다.

### 4.1

기준 포즈와의 거리를 잽니다. 굽힘·벌림·수향 오차를 각각의 허용 오차로 나눠 더합니다. 거리가 1보다 작으면 통과입니다.

**`PoseMatcher.swift`** — 기준 포즈와의 거리

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35]
import Foundation
import simd

struct PoseMatcher: Sendable {
    /// 굽힘각 허용 오차. 15도. 이보다 빡빡하면 초심자가 한 글자도 통과하지 못한다.
    var bendTolerance: Float = 0.26
    /// 수향 허용 오차. 25도. 손목은 굽힘각보다 재현성이 낮다.
    var orientationTolerance: Float = 0.44

    func match(_ feature: PoseFeature, to reference: PoseFeature, jamo: Jamo) -> PoseMatch {
        let signed = zip(feature.bend, reference.bend).map { $0 - $1 }
        let bend = signed.map { abs($0) }
        let spread = zip(feature.spread, reference.spread).map { abs($0 - $1) }
        let orientation = acos(clampf(dot(normalize(feature.palmNormal),
                                          normalize(reference.palmNormal)), -1, 1))

        // 관절마다 허용 오차가 다르다. 절대 오차를 쓰지 않고 허용 오차로 나눈 비율을 쓴다.
        let tolerance = bendTolerances(for: reference)
        let ratio = zip(bend, tolerance).map { $0 / $1 }

        // 수향은 글자를 가르는 신호이므로 굽힘각보다 무겁게 센다.
        let orientationWeight: Float = jamo.isOrientationCritical ? 1.4 : 0.8
        let overall = ratio.reduce(0, +) / Float(max(ratio.count, 1))
                    + spread.reduce(0, +) / Float(max(spread.count, 1)) / bendTolerance * 0.6
                    + orientation / orientationTolerance * orientationWeight

        // 평균만 보면 관절 하나가 크게 어긋나도 나머지 열넷에 묻혀 통과한다.
        // 중지만 22도 틀린 손은 통과시키면 안 되므로 최악 관절로 한 번 더 막는다.
        let worst = ratio.max() ?? 0
        let d = max(overall, worst)

        return PoseMatch(jamo: jamo, bendError: bend, spreadError: spread,
                         orientationError: orientation, distance: d, bendSigned: signed,
                         bendTolerance: tolerance)
    }
}
```

> Note: `bendTolerances(for:)`는 4.3에서 만듭니다. 지금은 관절 15개 모두에 같은 값을 돌려준다고 보면 됩니다.

### 4.2

**원래 설계 문서에 있던 버그.** 문서는 굽힘 오차의 *평균*만 썼습니다. 그러면 중지 하나만 20° 틀려도 나머지 열네 관절에 묻혀 그냥 통과합니다. 실제로 시뮬레이터에서 통과했습니다. 그래서 **최악 관절 항**을 하나 더 두고 둘 중 큰 값을 씁니다.

> Important: 📌 문서의 그림(중지 22° 초과 → 판정 실패)과 코드가 서로 어긋나 있었습니다. 그림 쪽이 옳습니다.

**`PoseMatcher.swift`** — 최악 관절 한 번 더

```swift, highlight=[8, 9, 10, 11]
import Foundation
import simd

struct PoseMatcher: Sendable {
    func match(_ feature: PoseFeature, to reference: PoseFeature, jamo: Jamo) -> PoseMatch {
        // …

        // 평균만 보면 관절 하나가 크게 어긋나도 나머지 열넷에 묻혀 통과한다.
        // 중지만 22도 틀린 손은 통과시키면 안 되므로 최악 관절로 한 번 더 막는다.
        let worst = ratio.max() ?? 0
        let d = max(overall, worst)
        // …
    }
}
```

### 4.3

**사람이 못 하는 것을 요구하면 안 됩니다.** 지화를 가르치는 쪽에서 나온 지적입니다 — **‘ㅊ’ 같은 글자는 약지와 새끼를 따로 접어야 하는데, 그게 안 되는 사람이 있습니다.** 억지로 하면 손가락이 부들부들 떨리고, 그래도 두 손가락이 완전히 갈라지지는 않습니다. 그래서 실제로 가르칠 때는 **대강 모양만 맞으면 인정해 준다**고 합니다.

이유는 손 구조에 있습니다. 약지와 새끼는 깊은손가락굽힘근의 힘줄을 나눠 쓰고 손등 쪽에서 힘줄끼리 서로 묶여 있어, 한쪽을 접으면 다른 쪽이 따라옵니다. 얼마나 갈라지는지는 사람마다 다릅니다. **되는 사람 기준으로 채점하면 안 되는 사람은 그 글자를 영영 통과하지 못합니다.**

그래서 **그 두 손가락의 허용 오차만 두 배로 넓힙니다.** 대상 글자를 손으로 적어 두지 않고, 기준 포즈가 약지와 새끼에 서로 다른 굽힘을 요구하는지 계산해서 자동으로 고릅니다. 나중에 자리표시자를 실측 포즈로 바꿔도 목록을 다시 손볼 일이 없습니다.

**`PoseMatcher.swift`** — 약지·새끼만 관대하게

```swift, highlight=[7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
import Foundation
import simd

struct PoseMatcher: Sendable {
    var bendTolerance: Float = 0.26
    var orientationTolerance: Float = 0.44
    /// 약지와 새끼를 서로 다르게 접어야 하는 글자에서 그 두 손가락에만 곱하는 허용 오차 배수.
    ///
    /// 두 손가락은 깊은손가락굽힘근의 힘줄을 나눠 쓰기 때문에 완전히 분리되지 않는다.
    /// 되는 사람도 있고 안 되는 사람도 있으며, 안 되는 사람은 손가락이 부들부들 떨린다.
    /// 실제 지화 교육에서도 이런 글자는 대강 모양만 맞으면 인정한다.
    /// 기계가 사람보다 엄격하면 배우는 사람이 지친다.
    var coupledFingerRelief: Float = 2

    // …

    /// 관절 15개의 허용 오차. 기본은 전부 같고, 약지·새끼 분리를 요구하는 글자에서만 그 여섯이 넓어진다.
    func bendTolerances(for reference: PoseFeature) -> [Float] {
        var t = [Float](repeating: bendTolerance, count: PoseFeature.bendCount)
        guard demandsFingerDecoupling(reference) else { return t }
        for i in (FingerName.ring.rawValue * 3)..<PoseFeature.bendCount {
            t[i] = bendTolerance * coupledFingerRelief
        }
        return t
    }

    /// 기준 포즈가 약지와 새끼에 서로 다른 굽힘을 요구하는가.
    /// 요구하는 글자만 자동으로 골라내므로 손으로 목록을 관리하지 않는다.
    /// 자리표시자 표에서는 ㄸ · ㅃ · ㅉ · ㅊ · ㅌ · ㅍ · ㅒ · ㅖ · ㅞ · ㅠ · ㅣ 가 걸린다.
    func demandsFingerDecoupling(_ reference: PoseFeature) -> Bool {
        guard reference.bend.count == PoseFeature.bendCount else { return false }
        let ring = FingerName.ring.rawValue * 3
        let little = FingerName.little.rawValue * 3
        let gap = (0..<3).map { abs(reference.bend[ring + $0] - reference.bend[little + $0]) }
        return (gap.max() ?? 0) > bendTolerance
    }
}
```

**숫자로 확인하면 이렇습니다.** ‘ㅊ’의 기준 포즈는 약지를 절반, 새끼를 거의 다 접으라고 요구합니다. 두 손가락이 함께 중간쯤에서 멈추는 손 — 분리가 안 되는 사람의 손 — 을 넣어 보면:

| | 거리 | 판정 |
| --- | --- | --- |
| 완화 전 | 1.27 | 실패 |
| 완화 후 | **0.63** | **통과** |
| 완화 후, 중지가 틀린 손 | 3.17 | 실패 |

세 번째 줄이 중요합니다. **완화는 약지와 새끼에만 걸립니다.** 중지가 틀린 손은 여전히 걸러집니다. 최악 관절 항도 그대로 살아 있습니다. 관대해진 것이 아니라, **관대해야 할 자리에서만 관대해진 것**입니다.

> Warning: ⚠️ 배수 2는 자리표시자 표에서 골라낸 값입니다. 실측 포즈로 교체한 뒤에는 3단계에서 나오는 **관절별 표준편차**로 다시 잡으세요. 약지·새끼를 분리하지 못하는 사람 여럿의 표준편차가 진짜 근거입니다. 감으로 정한 2를 그대로 두지 마세요.

### 4.4

관절마다 허용 오차가 다르면 **절대 오차끼리 비교하면 안 됩니다.** 30° 틀린 약지와 20° 틀린 중지 중 무엇을 먼저 고쳐야 하는지는, 각자의 허용 오차로 나눠 봐야 알 수 있습니다. 그 비율을 `PoseMatch`가 함께 들고 다닙니다.

**`PoseMatcher.swift`** — 판정 결과가 허용 오차를 함께 들고 다닌다

```swift, highlight=[15, 16, 20, 21, 22, 23, 24]
import Foundation
import simd

/// 기준 포즈와의 거리. 작을수록 정답에 가깝다.
struct PoseMatch: Equatable, Sendable {
    var jamo: Jamo
    /// 관절별 오차(라디안). 피드백 문장이 여기서 나온다.
    var bendError: [Float]
    var spreadError: [Float]
    var orientationError: Float
    /// 가중 합. 1 미만이면 통과.
    var distance: Float
    /// 어느 쪽으로 어긋났는지. 음수면 기준보다 덜 접혔다.
    var bendSigned: [Float]
    /// 관절 15개 각각의 허용 오차(라디안). 손가락마다 다를 수 있다.
    var bendTolerance: [Float]

    var passed: Bool { distance < 1 }

    /// 허용 오차로 나눈 관절별 오차. 1을 넘은 관절이 초과다.
    /// 손가락마다 허용 오차가 다르므로 절대 오차끼리 비교하면 안 된다.
    var bendRatio: [Float] {
        zip(bendError, bendTolerance).map { $0 / max($1, 1e-4) }
    }
}
```

### 4.5

오차가 가장 큰 관절 **하나만** 골라 문장으로 만듭니다. 여러 개를 한꺼번에 말하면 사용자는 아무것도 고치지 못합니다. 한 번에 하나 — 지침의 한 단계 한 개념 규칙을 피드백에도 그대로 적용합니다.

**`Coaching.swift`** — 한 번에 한 문장

```swift, highlight=[9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]
import Foundation

/// 틀렸다는 사실이 아니라 무엇을 어떻게 바꿔야 하는지를 말한다.
/// 한 번에 하나. 여러 개를 한꺼번에 말하면 사용자는 아무것도 고치지 못한다.
struct Coach: Sendable {
    var bendTolerance: Float = 0.26
    var orientationTolerance: Float = 0.44

    func advice(for match: PoseMatch) -> String? {
        guard !match.passed else { return nil }   // 통과했으면 말하지 않는다

        if match.orientationError > orientationTolerance {
            return "손바닥 방향을 바로잡아 주세요."
        }

        // 손가락마다 허용 오차가 다르므로 절대 오차가 아니라 허용 오차 대비 비율로 고른다.
        // 약지·새끼를 관대하게 보는 글자에서 그 두 손가락만 계속 지적하는 일을 막는다.
        let ratio = match.bendRatio
        guard let worst = ratio.enumerated().max(by: { $0.element < $1.element }),
              worst.element > 1 else {
            // 굽힘은 괜찮은데 거리가 남았다면 벌림이 원인이다.
            if let s = match.spreadError.enumerated().max(by: { $0.element < $1.element }),
               s.element > bendTolerance {
                let a = FingerName.allCases[s.offset], b = FingerName.allCases[s.offset + 1]
                return "\(a.korean)와 \(b.korean) 사이를 조금 더 붙여 보세요."
            }
            return nil
        }

        let finger = FingerName.allCases[worst.offset / 3]
        let tooStraight = match.bendSigned[worst.offset] < 0

        return tooStraight
            ? "\(finger.korean)를 조금 더 접어 주세요."
            : "\(finger.korean)를 조금 더 펴 주세요."
    }

    /// 약지와 새끼를 따로 접어야 하는 글자에서 한 번만 띄우는 안내.
    /// 두 손가락은 힘줄을 나눠 쓰기 때문에 완전히 분리되지 않는 사람이 많다.
    func note(for match: PoseMatch) -> String? {
        guard let base = match.bendTolerance.first,
              let ring = match.bendTolerance[safe: FingerName.ring.rawValue * 3],
              ring > base else { return nil }
        return "약지와 새끼는 힘줄을 나눠 써서 따로 접기 어렵습니다. 이 글자는 두 손가락을 넉넉하게 봅니다."
    }
}
```

> Tip: `note(for:)`는 **왜 통과가 됐는지**를 알려 주는 문장입니다. 규칙을 몰래 느슨하게 하면 사용자는 자기 손이 정확한 줄 압니다. 화면에 적어 두면 "이 글자는 원래 이렇게 본다"는 것을 배우게 됩니다.

### 4.6

프레임 단위 판정은 떨립니다. 같은 글자가 0.4초 유지되어야 확정하고, 확정한 뒤에는 조금 더 관대하게 봅니다. 손이 살짝 흔들려도 판정이 풀리지 않게 하는 히스테리시스입니다.

**`Stabilizer.swift`** — 0.4초 유지해야 확정

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
import Foundation

@MainActor
final class Stabilizer {
    /// 이 시간 동안 유지되어야 통과. 짧으면 스쳐 지나가며 오답이 통과된다.
    var dwell: TimeInterval = 0.4
    /// 통과한 뒤에는 더 관대하게 본다. 손이 조금 흔들려도 풀리지 않게.
    var holdMultiplier: Float = 1.35

    func feed(_ best: PoseMatch, at time: TimeInterval) {
        let threshold: Float = (confirmed == best.jamo) ? holdMultiplier : 1
        guard best.distance < threshold else {
            candidate = nil
            confirmed = nil
            progress = 0
            return
        }
        if candidate != best.jamo {
            candidate = best.jamo
            since = time
            progress = 0
        } else {
            progress = min((time - since) / dwell, 1)
            if time - since >= dwell { confirmed = best.jamo }
        }
    }
}
```

### 4.7

**여기서 조각들을 하나로 묶습니다.** 특징 추출 · 판정 · 안정화 · 교정 문장 · 오버레이를 매 프레임 한 곳에서 돌리는 `TutorModel`이 앱의 심장입니다. 화면은 이 객체 하나만 바라봅니다.

**`TutorModel.swift`** — 매 프레임 도는 루프

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
import ARKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TutorModel {
    // …

    private func consume(_ sample: HandSample) {
        let t0 = CFAbsoluteTimeGetCurrent()

        guard let reference = ReferenceLibrary.shared.reference(for: target) else { return }
        let match = matcher.match(sample.feature, to: reference, jamo: target)

        // 목표와 다른 글자를 짚고 있으면 그것도 알려 준다.
        let ranked = matcher.rank(sample.feature, in: ReferenceLibrary.shared)

        stabilizer.feed(match, at: sample.timestamp)

        currentMatch = match
        bestGuess = ranked.first
        advice = coach.advice(for: match)
        fingerNote = coach.note(for: match)
        confirmed = stabilizer.confirmed
        holdProgress = stabilizer.progress

        overlay.update(match: match,
                       reference: reference,
                       wrist: sample.wristTransform,
                       span: sample.handSpan,
                       tolerances: match.bendTolerance,
                       mode: overlayMode)

        lastFrameCost = (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }
}
```

> Note: 오버레이에도 **관절별** 허용 오차를 그대로 넘깁니다. 약지·새끼를 관대하게 보는 글자에서 그 두 손가락이 늘 진하게 보이면, 사용자는 고칠 수 없는 것을 고치려 듭니다.

### 4.8

실기기가 아니면 가짜 손으로 **자동 전환**합니다. 이 분기 하나 덕분에 Vision Pro가 없어도 5단계까지 전부 확인할 수 있습니다.

> Important: 📌 이 파일이 빠지면 앱에 화면이 하나도 뜨지 않습니다. 실제로 이 튜토리얼 초판에서 빠져 있었고, 문서에 실린 코드만으로 새 프로젝트를 만들어 빌드해 보고서야 발견했습니다.

**`TutorModel.swift`** — 실기기가 없으면 가짜 손으로

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
import ARKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TutorModel {
    // …

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        if HandTrackingFeed.isSupported {
            usingMockData = false
            liveFeed.preferredChirality = handedness
            await liveFeed.start()
            pump = Task { [weak self] in
                guard let self else { return }
                for await sample in self.liveFeed.samples { self.consume(sample) }
            }
        } else {
            usingMockData = true
            mockFeed.target = target
            await mockFeed.start()
            pump = Task { [weak self] in
                guard let self else { return }
                for await sample in self.mockFeed.samples { self.consume(sample) }
            }
        }
    }
}
```

### 4.9

슬라이더로 오차를 20°까지 올려 봅니다. **거리 1.41 · “중지를 조금 더 펴 주세요.”** 가 뜨면 4단계 성공입니다. 오차를 0으로 내리면 통과로 바뀝니다.

**`TutorView.swift`** — 목 데이터에 오차를 실어 보는 슬라이더

```swift, highlight=[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
import ARKit
import SwiftUI

private struct MockErrorSlider: View {
    @Environment(TutorModel.self) private var model
    @State private var degrees: Double = 20

    var body: some View {
        VStack(alignment: .leading) {
            Text("목 데이터 오차 \(Int(degrees))° (중지)")
                .font(.caption)
            Slider(value: $degrees, in: 0...45, step: 1)
                .onChange(of: degrees) { _, new in
                    model.setMockError(Float(new * .pi / 180))
                }
        }
    }
}
```

### 실행 결과

**4단계를 마치면 나오는 화면**

![4단계 실행 화면](step4.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 오차 20°에서 실패하고 중지를 지목한다
- 오차 0°에서 통과로 바뀐다
- 0.4초 유지해야 확정된다
- ‘ㅊ’을 고르면 약지·새끼 줄이 **완화**로 뜨고, 안내 문장이 함께 나온다

#### 안 되면 확인할 것

- 항상 통과한다면 최악 관절 항이 빠진 것입니다. 평균만 쓰면 이 증상이 나옵니다.
- 문장이 안 나오면 `advice`가 통과 상태에서 `nil`을 돌려주는지 확인하세요 — 통과했으면 말하지 않는 것이 맞습니다.
- ‘ㅊ’에서 약지·새끼가 여전히 빡빡하면 `demandsFingerDecoupling`이 `false`를 돌려주고 있는 것입니다. 기준 포즈의 약지·새끼 굽힘 차이가 `bendTolerance`보다 커야 걸립니다.
- **모든 글자가 완화된다면** 기준 표가 비어 `bend`가 전부 0인 경우입니다. 3단계 표를 확인하세요.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-5-Expand-to-40-Characters>
