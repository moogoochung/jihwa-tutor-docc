# 3. 정답을 기록한다

채점을 하려면 정답이 있어야 합니다. 그 정답을 만드는 화면을 먼저 만듭니다.

## Overview

> Note: **이 단계에서 새로 만드는 파일** — `ReferenceLibrary.swift`. `import Foundation`과 `import simd`만 있으면 됩니다. 이 파일은 손 추적을 직접 만지지 않으므로 ARKit이 필요 없습니다.

### 3.1

**여기가 원래 설계 문서가 통째로 비워 둔 자리입니다.** "숙련자 포즈를 등록한다"고만 하고 방법이 없으면 아무도 다음 단계로 못 갑니다. 그래서 기록 화면을 튜토리얼 한 단계로 만듭니다.

**`ReferenceLibrary.swift`** — 기준 포즈 표

```swift, highlight=[6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
import Foundation
import simd

// …

/// 기준 포즈 표. 40자를 여기에 채운다.
@MainActor
final class ReferenceLibrary {
    static let shared = ReferenceLibrary()

    private(set) var table: [Jamo: PoseFeature] = [:]
    /// 실측으로 교체된 자모. 자리표시자와 구분한다.
    private(set) var measured: Set<Jamo> = []

    init() {
        for (jamo, recipe) in Self.placeholders {
            table[jamo] = recipe.feature()
        }
    }
    // …
}
```

### 3.2

같은 글자를 여러 벌 기록해 평균을 냅니다. 그리고 **관절별 표준편차를 함께 돌려줍니다.** 이 값의 두 배가 초기 허용 오차가 됩니다 — 허용 오차를 감으로 정하지 않는 방법입니다.

**`ReferenceLibrary.swift`** — 여러 벌의 평균과 표준편차

```swift, highlight=[8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37]
import Foundation
import simd

@MainActor
final class ReferenceLibrary {
    // …

    /// 숙련자 포즈 여러 벌을 평균 내 기준 포즈로 등록한다.
    /// 관절별 표준편차가 곧 초기 허용 오차가 된다.
    @discardableResult
    func register(_ jamo: Jamo, samples: [PoseFeature]) -> (mean: PoseFeature, stdDev: [Float])? {
        guard !samples.isEmpty else { return nil }
        let n = Float(samples.count)

        var bend = [Float](repeating: 0, count: PoseFeature.bendCount)
        var spread = [Float](repeating: 0, count: PoseFeature.spreadCount)
        var palm = SIMD3<Float>.zero
        for s in samples {
            for i in 0..<PoseFeature.bendCount { bend[i] += s.bend[i] }
            for i in 0..<PoseFeature.spreadCount { spread[i] += s.spread[i] }
            palm += s.palmNormal
        }
        bend = bend.map { $0 / n }
        spread = spread.map { $0 / n }
        palm = length(palm) > 1e-5 ? normalize(palm) : SIMD3(0, 0, 1)

        let stdDev = (0..<PoseFeature.bendCount).map { i -> Float in
            let v = samples.reduce(Float(0)) { $0 + pow($1.bend[i] - bend[i], 2) } / n
            return sqrt(v)
        }

        let mean = PoseFeature(bend: bend, spread: spread, palmNormal: palm)
        table[jamo] = mean
        measured.insert(jamo)
        confusableCache = nil
        return (mean, stdDev)
    }
}
```

### 3.3

사람이 읽고 고칠 수 있는 형태로도 기준 포즈를 적을 수 있게 해 둡니다. curl 0은 완전히 편 손가락, 1은 완전히 접은 손가락입니다. 실측 데이터가 없는 자모를 임시로 채울 때 씁니다.

**`ReferenceLibrary.swift`** — 사람이 손으로 적는 포즈

```swift, highlight=[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
import Foundation
import simd

/// 자모 하나의 기준 포즈를 사람이 읽고 쓸 수 있는 형태로 적은 것.
/// curl 0 = 완전히 편 상태, 1 = 완전히 접은 상태.
struct PoseRecipe: Sendable {
    var curl: [Float]              // 손가락 5개
    var spread: [Float]            // 인접 4쌍, 0 = 붙임, 1 = 최대로 벌림
    var palm: SIMD3<Float>         // 손목 기준 손바닥 법선

    func feature() -> PoseFeature {
        // 손가락 하나의 굽힘은 뿌리·중간·끝에 각각 다르게 실린다.
        let weight: [Float] = [0.9, 1.1, 1.0]
        let maxBend: Float = 1.5   // 라디안. 완전히 접은 관절의 굽힘각.
        var bend: [Float] = []
        for c in curl {
            for w in weight { bend.append(clampf(c, 0, 1) * maxBend * w) }
        }
        let maxSpread: Float = 0.45
        return PoseFeature(bend: bend,
                           spread: spread.map { clampf($0, 0, 1) * maxSpread },
                           palmNormal: normalize(palm))
    }
}
```

### 3.4

**자리표시자와 실측을 화면에서 구분합니다.** ‘ㄱ’을 다섯 벌 기록하고 평균을 내면 관절별 표준편차 15개가 도 단위로 나옵니다. 그 글자는 `measured`에 들어가고, 화면 위쪽 경고가 사라집니다. 이 경고가 남아 있는 동안 그 글자의 판정 결과는 믿을 것이 못 됩니다.

**`TutorView.swift`** — 자리표시자 경고

```swift, highlight=[10, 11, 12, 13, 14, 15]
import ARKit
import SwiftUI

struct TutorView: View {
    // …

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // …
            if ReferenceLibrary.shared.isPlaceholder(model.target) {
                Label("이 글자의 기준 포즈는 아직 자리표시자입니다. 숙련자 포즈로 교체해야 합니다.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
    }
}
```

### 실행 결과

**3단계를 마치면 나오는 화면**

![3단계 실행 화면](step3.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 기록 벌 수가 올라간다
- 평균을 내면 관절별 표준편차 15개가 나온다
- 실측으로 교체한 글자에서는 노란 경고가 사라진다

#### 안 되면 확인할 것

- 가짜 손은 떨림이 작아서 표준편차가 0.2~0.4° 수준으로 나옵니다. 진짜 손은 훨씬 큽니다 — 그래서 실측이 필요합니다.
- `ReferenceLibrary`는 `@MainActor`입니다. 백그라운드 태스크에서 직접 부르면 컴파일 에러가 납니다.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-4-Scoring-and-Coaching>
