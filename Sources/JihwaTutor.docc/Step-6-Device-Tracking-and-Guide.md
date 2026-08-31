# 6. 실기기: 진짜 손과 3D 가이드

여기서부터는 Vision Pro가 필요합니다. 앞의 다섯 단계는 실기기 없이도 전부 돌아갑니다.

## Overview

@Row {
    @Column {
        ## 30분
        **예상 소요 시간**

        @Small {
            코드를 직접 따라 치는 기준입니다.
        }
    }
    @Column(size: 2) {
        **이 단계에서 만드는 파일**

        `HandTrackingFeed.swift`(`ARKit` · `simd` · `OSLog` · `QuartzCore`) · `GuideOverlay.swift`(`UIKit` · `RealityKit` · `simd`) · `PracticeSpace.swift`(`RealityKit` · `SwiftUI`). 여기서 처음으로 `import RealityKit`이 등장합니다 — 3D 뼈대를 그리는 것은 SwiftUI가 아니라 RealityKit의 일입니다. **이 단계는 Apple Vision Pro 실기기가 필요합니다.**
    }
}


### 6.1

진짜 손 경로를 붙입니다. 1단계에서 정의한 `HandFeed` 구멍에 그대로 끼워 넣기만 하면 됩니다. 뒷단은 한 줄도 고치지 않습니다 — 1단계에서 타입을 맞춰 둔 보상입니다.

**`HandTrackingFeed.swift`** — ARKit 세션 시작

```swift, highlight=[11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
import ARKit
import simd
import OSLog
import QuartzCore

@MainActor
final class HandTrackingFeed: HandFeed {
    private let session = ARKitSession()
    // …

    func start() async {
        guard Self.isSupported else {
            logger.notice("이 기기에서는 손 추적을 쓸 수 없습니다. 목 데이터 경로를 쓰세요.")
            return
        }
        do {
            try await session.run([provider])
        } catch {
            logger.error("ARKitSession 시작 실패: \(error.localizedDescription, privacy: .public)")
            return
        }

        task = Task { [weak self] in
            guard let self else { return }
            for await update in self.provider.anchorUpdates {
                guard !Task.isCancelled else { break }
                self.handle(update.anchor)
            }
        }
    }
}
```

### 6.2

**손 데이터는 기기 밖으로 내보내지 않습니다.** 관절 좌표와 카메라 프레임을 파일·로그·네트워크·분석 도구 어디에도 남기지 않습니다. 학습 데이터를 모을 때도 좌표가 아니라 익명화된 특징 벡터만 남깁니다.

**`HandTrackingFeed.swift`** — 앵커 하나를 `HandSample`로

```swift, highlight=[10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28]
import ARKit
import simd
import OSLog
import QuartzCore

@MainActor
final class HandTrackingFeed: HandFeed {
    // …

    private func handle(_ anchor: HandAnchor) {
        guard anchor.isTracked,
              anchor.chirality == preferredChirality,
              let skeleton = anchor.handSkeleton,
              let feature = PoseFeature.extract(from: skeleton, chirality: anchor.chirality)
        else { return }

        let wrist = skeleton.joint(.wrist).anchorFromJointTransform
        let knuckle = skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform
        let span = length((wrist.inverse * knuckle).columns.3.xyz)

        continuation?.yield(
            HandSample(feature: feature,
                       chirality: anchor.chirality,
                       wristTransform: anchor.originFromAnchorTransform * wrist,
                       handSpan: span,
                       timestamp: CACurrentMediaTime())
        )
    }
}
```

### 6.3

왼손은 특징 추출 단계에서 x축을 뒤집어, 오른손 기준표 하나로 판정합니다. 기준 포즈를 두 벌 만들 필요가 없습니다.

**`PoseFeature.swift`** — 왼손을 오른손으로 뒤집기

```swift, highlight=[9, 10, 11, 12, 13, 14, 15, 16]
import ARKit
import simd

struct PoseFeature: Equatable, Codable, Sendable {
    static func extract(from skeleton: HandSkeleton,
                        chirality: HandAnchor.Chirality = .right) -> PoseFeature? {
        // …

        let mirror: Float = (chirality == .left) ? -1 : 1

        func local(_ name: HandSkeleton.JointName) -> SIMD3<Float> {
            let m = toLocal * skeleton.joint(name).anchorFromJointTransform
            var p = m.columns.3.xyz
            p.x *= mirror
            return p
        }
        // …
    }
}
```

### 6.4

정답 손 모양을 반투명 뼈대로 겹칩니다. 오차가 큰 관절만 진하게 만드는데, 색을 하나 더 쓰는 대신 **투명도**로 구분해 색맹 사용자도 읽을 수 있게 합니다. 진하기의 기준은 **관절마다 다른 허용 오차**입니다 — 약지·새끼를 관대하게 보는 글자에서 그 두 손가락이 늘 진하게 보이면, 사용자는 고칠 수 없는 것을 고치려 듭니다.

**`GuideOverlay.swift`** — 오차가 큰 관절만 진하게

```swift, highlight=[9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
import UIKit
import RealityKit
import simd

@MainActor
final class GuideOverlay {
    // …

    /// 관절마다 허용 오차가 다르다. 약지·새끼를 관대하게 보는 글자에서
    /// 그 두 손가락이 늘 진하게 보이면 사용자는 고칠 수 없는 것을 고치려 든다.
    func highlight(_ errors: [Float], tolerances: [Float]) {
        for (i, bone) in bones.enumerated() where i < errors.count {
            let tolerance = i < tolerances.count ? tolerances[i] : 0.26
            let over = min(errors[i] / max(tolerance, 1e-4), 2)
            bone.components.set(
                ModelComponent(mesh: boneMesh,
                               materials: [Self.material(opacity: 0.15 + 0.35 * over)])
            )
        }
    }
}
```

### 6.5

겹쳐 보기와 나란히 보기를 **둘 다** 만들고 사용자가 고르게 합니다. 초심자는 나란히 두는 쪽을, 교정 단계에서는 겹치는 쪽을 선호하는 경향이 있습니다.

**`GuideOverlay.swift`** — 손목에 맞춰 세우기

```swift, highlight=[9, 10, 11, 12, 13, 14, 15, 16, 17]
import UIKit
import RealityKit
import simd

@MainActor
final class GuideOverlay {
    // …

    func align(wrist: simd_float4x4, span: Float, mode: Mode) {
        var t = Transform(matrix: wrist)
        t.scale = SIMD3(repeating: max(span / 0.09, 0.5))
        if mode == .sideBySide {
            // 손 오른쪽 12cm 옆에 나란히 세운다.
            t.translation += SIMD3(0.12, 0, 0)
        }
        root.transform = t
    }
}
```

### 6.6

**몰입 공간에 뼈대를 올립니다.** 화면은 `RealityView` 하나와 시작·정지 두 줄이 전부입니다. 손 추적이 몰입 공간에서만 동작하므로, 공간이 열릴 때 시작하고 닫힐 때 멈추는 것이 자연스러운 수명입니다.

**`PracticeSpace.swift`** — 몰입 공간

```swift, highlight=[4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
import RealityKit
import SwiftUI

/// 손 스켈레톤 추적은 몰입 공간에서만 동작한다.
struct PracticeSpace: View {
    @Environment(TutorModel.self) private var model

    var body: some View {
        RealityView { content in
            content.add(model.overlay.root)
        }
        .task {
            await model.start()
        }
        .onDisappear {
            model.stop()
        }
    }
}
```

### 실행 결과

**6단계 실행 화면**

*이 단계는 실기기에서만 확인할 수 있습니다.  
시뮬레이터에는 손 스켈레톤 앵커가 오지 않습니다.*

### 체크포인트

#### 여기까지 하면

- 실기기에서 손을 들면 판정이 시작된다
- 오차가 큰 관절이 진하게 보인다

#### 안 되면 확인할 것

- 시뮬레이터에서는 앵커가 오지 않습니다. `HandTrackingProvider.isSupported`가 false면 자동으로 가짜 손으로 넘어가게 해 두었습니다.
- 몰입 공간을 열지 않으면 손 추적이 시작되지 않습니다.
- `Cannot find 'RealityView' in scope` — `import RealityKit`이 빠졌습니다.

### 계속하기

- <doc:JihwaTutor>
- <doc:Limits-and-References>
