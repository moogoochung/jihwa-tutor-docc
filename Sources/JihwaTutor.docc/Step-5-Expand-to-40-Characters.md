# 5. 40자로 늘린다

한 글자가 되면 나머지는 표를 채우는 일입니다. 다만 채우면서 무엇이 서로 헷갈리는지 기록해야 합니다.

## Overview

> Note: **이 단계에서 새로 만드는 파일** — `TutorView.swift`(`ARKit` · `SwiftUI`) · `JamoPicker.swift` · `VerdictCard.swift` · `ErrorChart.swift`(셋 다 `SwiftUI`만). 화면 세 개는 SwiftUI 하나로 충분하고, `TutorView`만 손 좌우 설정 때문에 `import ARKit`이 더 필요합니다.

### 5.1

자음 19자와 모음 21자를 표로 채웁니다. 손바닥 방향으로 갈리는 글자에는 표시를 남겨, 그 글자들만 수향에 더 큰 가중치를 줍니다.

**`Jamo.swift`** — 수향으로 갈리는 글자

```swift, highlight=[6, 7, 8, 9, 10, 11]
import Foundation

enum Jamo: String, CaseIterable, Identifiable, Sendable {
    // …

    /// 손 모양이 같고 손바닥 방향으로만 갈리는 자모.
    /// 회전 정규화를 적용하면 이 글자들이 서로 뭉개진다.
    /// 표준 손 모양은 국립국어원 한국수어사전에서 반드시 재확인할 것.
    static let orientationCritical: Set<Jamo> = [.ssangSiot, .o, .yo, .u, .yu, .eu, .i]

    var isOrientationCritical: Bool { Jamo.orientationCritical.contains(self) }
}
```

### 5.2

40자 전체와 비교해 가장 가까운 순으로 줄을 세웁니다. 40번의 비교는 사실상 공짜입니다 — 프레임당 1ms 예산 안에 충분히 들어갑니다.

**`PoseMatcher.swift`** — 40자를 한 번에 줄 세우기

```swift, highlight=[7, 8, 9, 10, 11, 12, 13]
import Foundation
import simd

struct PoseMatcher: Sendable {
    // …

    /// 40자 전체와 비교해 가장 가까운 순으로 돌려준다. 프레임당 1ms 예산 안에 든다.
    @MainActor
    func rank(_ feature: PoseFeature, in library: ReferenceLibrary) -> [PoseMatch] {
        library.all()
            .map { match(feature, to: $0.value, jamo: $0.key) }
            .sorted { $0.distance < $1.distance }
    }
}
```

### 5.3

**표를 채우면서 반드시 해야 할 일.** 기준 표 안에서 서로 너무 가까운 자모 쌍을 자동으로 찾습니다. 거리가 1 미만인 쌍은 현재 표로는 갈라낼 수 없습니다. 이 목록에만 나중에 CoreML 보조 분류기를 붙이면 됩니다.

> Warning: ⚠️ 자리표시자 표로는 갈라내지 못하는 쌍이 16개 나옵니다. 실측 포즈로 교체하면 줄어듭니다. 화면 위쪽에 그 개수가 항상 표시됩니다.

**`ReferenceLibrary.swift`** — 서로 헷갈리는 쌍 찾기

```swift, highlight=[8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
import Foundation
import simd

@MainActor
final class ReferenceLibrary {
    // …

    func confusablePairs(threshold: Float = 1, matcher: PoseMatcher = PoseMatcher())
        -> [(Jamo, Jamo, Float)] {
        if threshold == 1, let cached = confusableCache { return cached }
        let items = all().sorted { $0.key.rawValue < $1.key.rawValue }
        var out: [(Jamo, Jamo, Float)] = []
        for i in items.indices {
            for j in (i + 1)..<items.count {
                let d = matcher.match(items[i].value, to: items[j].value, jamo: items[j].key).distance
                if d < threshold { out.append((items[i].key, items[j].key, d)) }
            }
        }
        let sorted = out.sorted { $0.2 < $1.2 }
        if threshold == 1 { confusableCache = sorted }
        return sorted
    }
}
```

### 5.4

창 화면을 조립합니다. 자모 선택 · 판정 카드 · 오차 그래프 · 설정을 차례로 세우고, 아래 오너먼트에 몰입 공간을 여닫는 버튼을 답니다.

**`TutorView.swift`** — 창 화면 조립

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34]
import ARKit
import SwiftUI

struct TutorView: View {
    @Environment(TutorModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var spaceOpen = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    JamoPicker(selection: $model.target)
                    VerdictCard()
                    ErrorChart()
                    settings
                }
                .padding(28)
            }
            .navigationTitle("지화 튜터")
            .toolbar {
                ToolbarItem(placement: .bottomOrnament) {
                    Button(spaceOpen ? "연습 끝내기" : "연습 시작") {
                        Task { await toggleSpace() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
```

### 5.5

자음 19 · 모음 21 그리드입니다. 손바닥 방향으로 갈리는 글자에는 **점을 하나 찍어** 눈에 보이게 합니다.

**`JamoPicker.swift`** — 40자 그리드

```swift, highlight=[7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36]
import SwiftUI

struct JamoPicker: View {
    @Binding var selection: Jamo
    // …

    private func section(_ title: String, _ items: [Jamo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { jamo in
                    Button {
                        selection = jamo
                    } label: {
                        Text(jamo.rawValue)
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(alignment: .topTrailing) {
                                if jamo.isOrientationCritical {
                                    Circle()
                                        .frame(width: 5, height: 5)
                                        .foregroundStyle(.tint)
                                        .padding(4)
                                }
                            }
                    }
                    .buttonStyle(.bordered)
                    .background(jamo == selection ? Color.accentColor.opacity(0.35) : .clear,
                                in: .rect(cornerRadius: 12))
                }
            }
            Text("점이 붙은 글자는 손바닥 방향으로 갈립니다. 회전 정규화를 적용하면 서로 구별할 수 없게 됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
```

### 5.6

판정 카드입니다. 유지 시간이 링으로 차오르고 통과하면 초록으로 바뀝니다. 목표와 다른 글자에 더 가까우면 그것도 함께 알려 줍니다 — 어느 쪽으로 틀렸는지 아는 것이 학습에 도움이 됩니다. 그리고 4.5에서 만든 **약지·새끼 안내**가 여기에 붙습니다.

**`VerdictCard.swift`** — 판정과 교정 문장

```swift, highlight=[21, 22, 23, 24, 25]
import SwiftUI

struct VerdictCard: View {
    @Environment(TutorModel.self) private var model

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 24) {
                // … 유지 시간 링 …

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(passed ? .green : .primary)

                    if let advice = model.advice {
                        Label(advice, systemImage: "hand.point.up.left")
                            .font(.body)
                    }

                    if let note = model.fingerNote, !passed {
                        Label(note, systemImage: "hand.raised.fingers.spread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let best = model.bestGuess, best.jamo != model.target, !passed {
                        Text("지금 손 모양은 ‘\(best.jamo.rawValue)’에 더 가깝습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(headline + (model.advice.map { ". " + $0 } ?? "")))
        }
    }
}
```

### 5.7

손가락별 오차 막대에는 허용 오차선을 함께 그려 지금 어디쯤인지 눈으로 보이게 합니다. **선의 위치는 손가락마다 다를 수 있습니다** — 약지·새끼를 관대하게 보는 글자에서는 그 두 줄의 선만 오른쪽으로 물러납니다.

**`ErrorChart.swift`** — 손가락별 허용 오차선

```swift, highlight=[9, 10, 37, 43]
import SwiftUI

struct ErrorChart: View {
    @Environment(TutorModel.self) private var model
    // …

    private func row(_ finger: FingerName) -> some View {
        let degrees = worstDegrees(finger)
        let tolerance = toleranceDegrees(finger)
        let relaxed = tolerance > CGFloat(model.toleranceDegrees) + 0.5
        let over = degrees > tolerance
        return HStack(spacing: 12) {
            Text(finger.korean)
                .font(.callout)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                let full = geo.size.width
                let unit: CGFloat = full / 45.0     // 0…45도 눈금
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 10)
                    Capsule()
                        .fill(over ? Color.orange : Color.green)
                        .frame(width: min(degrees * unit, full), height: 10)
                    Rectangle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 1.5, height: 18)
                        .offset(x: tolerance * unit)
                }
            }
            .frame(height: 20)

            Text("\(Int(degrees))°")
                .font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .trailing)

            Text(over ? "초과" : (relaxed ? "완화" : "통과"))
                .font(.caption2)
                .frame(width: 34)
                .foregroundStyle(over ? .orange : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finger.korean) 오차 \(Int(degrees))도, 허용 오차 \(Int(tolerance))도, \(over ? "초과" : "통과")")
    }
}
```

### 5.8

색이 아니라 **길이와 형태**로 구분하고, 모든 판정에 접근성 레이블을 붙입니다. 청각장애 학습자가 주 사용자인 앱에서 소리로만 알려 주는 설계는 성립하지 않고, 색맹 사용자도 읽을 수 있어야 합니다. 허용 오차도 레이블에 함께 읽어 줍니다 — 화면에서 선의 위치로 보이던 정보가 소리로도 남아야 합니다.

**`ErrorChart.swift`** — 손가락별 대표 오차와 허용 오차

```swift, highlight=[6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
import SwiftUI

struct ErrorChart: View {
    // …

    /// 손가락마다 허용 오차가 다를 수 있다.
    /// 약지와 새끼를 따로 접어야 하는 글자에서는 그 둘만 넓다.
    private func toleranceDegrees(_ finger: FingerName) -> CGFloat {
        guard let t = model.currentMatch?.bendTolerance,
              t.count == PoseFeature.bendCount else { return CGFloat(model.toleranceDegrees) }
        return CGFloat(t[finger.rawValue * 3] * 180 / .pi)
    }

    /// 손가락 하나에 관절 3개. 그중 가장 큰 오차를 대표값으로 쓴다.
    private func worstDegrees(_ finger: FingerName) -> CGFloat {
        guard let errors = model.currentMatch?.bendError,
              errors.count == PoseFeature.bendCount else { return 0 }
        let slice = errors[(finger.rawValue * 3)..<(finger.rawValue * 3 + 3)]
        return CGFloat((slice.max() ?? 0) * 180 / .pi)
    }
}
```

### 5.9

**40자 그리드에서 글자를 고르면 그 글자로 채점이 바뀝니다.** 목표가 바뀌면 이전 글자의 판정 결과와 문장은 즉시 버려야 합니다. 남겨 두면 새 글자를 짚는 동안 이전 글자의 교정 문장이 잠깐 보입니다. 여기까지가 시뮬레이터에서 확인할 수 있는 전부입니다.

**`TutorModel.swift`** — 목표가 바뀌면 판정을 비운다

```swift, highlight=[9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
import ARKit
import Observation
import SwiftUI

@MainActor
@Observable
final class TutorModel {

    // 학습 목표
    var target: Jamo = .giyeok {
        didSet {
            stabilizer.reset()
            mockFeed.target = target
            currentMatch = nil
            advice = nil
            fingerNote = nil
        }
    }
    // …
}
```

### 실행 결과

**5단계를 마치면 나오는 화면**

![5단계 실행 화면](step5.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 자음 19 + 모음 21 = 40개 버튼이 보인다
- 글자를 바꾸면 판정 대상이 바뀐다
- 헷갈리는 쌍 개수가 표시된다
- ‘ㅊ’을 고르면 약지·새끼 줄의 허용 오차선이 오른쪽으로 물러난다
- 여기까지의 파일만으로 빌드가 통과한다

#### 안 되면 확인할 것

- 첫 렌더에서 모음 그리드가 비어 보일 수 있습니다. 한 번 클릭하면 정상으로 돌아옵니다 (LazyVGrid 레이아웃 타이밍).
- 모든 글자가 같은 점수로 나오면 기준 표가 비어 있는 것입니다.
- 허용 오차선이 모든 손가락에서 같은 자리라면 `toleranceDegrees(_:)`가 아니라 `model.toleranceDegrees`를 그대로 쓰고 있는 것입니다.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-6-Device-Tracking-and-Guide>
