# 2. 관절을 22개의 숫자로

손이 방 어디에 있든, 어른 손이든 아이 손이든 같은 값이 나오게 만듭니다.

## Overview

@Row {
    @Column {
        ## 35분
        **예상 소요 시간**

        @Small {
            코드를 직접 따라 치는 기준입니다.
        }
    }
    @Column(size: 2) {
        **이 단계에서 만드는 파일**

        `PoseFeature.swift` · `PoseFeature+Angles.swift`. 둘 다 `import ARKit`(관절 이름 `HandSkeleton.JointName`)과 `import simd`(벡터 연산 `dot` · `cross` · `length`)가 필요합니다. **이 튜토리얼에서 수학이 가장 몰려 있는 단계입니다.**
    }
}


### 2.1

27개 관절 좌표를 그대로 쓰면 손 위치와 크기에 휘둘립니다. 그래서 **굽힘 15 + 벌림 4 + 손바닥 법선 3 = 22개**의 숫자로 줄입니다.

**`PoseFeature.swift`** — 22차원 특징

```swift, highlight=[6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
import ARKit
import simd

// …

/// 지화 한 글자를 판별하는 데 쓰는 22차원 특징.
struct PoseFeature: Equatable, Codable, Sendable {
    /// 손가락 5개 × 관절 3개. 라디안. 편 손가락은 0에 가깝다.
    var bend: [Float]           // 15
    /// 인접한 손가락 사이 벌림각. 라디안.
    var spread: [Float]         // 4
    /// 손바닥 법선. 수향을 담는다. 정규화로 지우지 않는다.
    var palmNormal: SIMD3<Float> // 3

    static let bendCount = 15
    static let spreadCount = 4
    static let dimension = bendCount + spreadCount + 3   // 22
    // …
}
```

### 2.2

**여기가 이 프로젝트에서 제일 중요한 판단입니다.** 위치와 손 크기는 지우지만 **회전은 지우지 않습니다**. 흔히 쓰는 회전 정규화를 그대로 적용하면 손 모양이 같고 손바닥 방향만 다른 글자들이 서로 뭉개집니다.

> Warning: ⚠️ 몇 글자가 손바닥 방향으로 갈리는지는 국립국어원 한국수어사전에서 직접 확인하세요. 이 튜토리얼은 그 숫자를 검증하지 않았습니다.

**`PoseFeature.swift`** — 손목을 원점으로 옮기고 손 크기로 나눈다

```swift, highlight=[7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
import ARKit
import simd

struct PoseFeature: Equatable, Codable, Sendable {
    // …

    /// 손목을 원점으로 옮기고 손 크기로 나눈 뒤 각도를 잰다.
    /// 왼손은 x축을 뒤집어 오른손 기준표 하나로 판정한다.
    static func extract(from skeleton: HandSkeleton,
                        chirality: HandAnchor.Chirality = .right) -> PoseFeature? {
        let wrist = skeleton.joint(.wrist)
        guard wrist.isTracked else { return nil }

        let toLocal = wrist.anchorFromJointTransform.inverse
        let mirror: Float = (chirality == .left) ? -1 : 1

        func local(_ name: HandSkeleton.JointName) -> SIMD3<Float> {
            let m = toLocal * skeleton.joint(name).anchorFromJointTransform
            var p = m.columns.3.xyz
            p.x *= mirror
            return p
        }

        // 손 크기로 나눠 어른 손과 아이 손을 같은 자리에 놓는다.
        let span = length(local(.middleFingerKnuckle))
        guard span > 0.02 else { return nil }

        let f = PoseFeature(bend: bendAngles(local),
                            spread: spreadAngles(local),
                            palmNormal: palmNormal(local))
        return f.isWellFormed ? f : nil
    }
}
```

### 2.3

굽힘각은 세 관절이 이루는 각으로 잽니다. 편 손가락은 0에 가깝고, 접을수록 커집니다. 0으로 나누는 경우를 반드시 막아야 합니다 — 관절이 겹쳐 보이는 프레임이 실제로 들어옵니다.

**`PoseFeature+Angles.swift`** — 관절 세 개로 각 하나

```swift, highlight=[4, 5, 6, 7, 8, 9, 10]
import ARKit
import simd

/// 세 관절이 이루는 굽힘각. 편 손가락은 0에 가깝다.
func jointAngle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
    let u = a - b, v = c - b
    let lu = length(u), lv = length(v)
    guard lu > 1e-5, lv > 1e-5 else { return 0 }   // 0으로 나누기 방지
    return .pi - acos(clampf(dot(u, v) / (lu * lv), -1, 1))
}
```

### 2.4

손바닥 법선은 손목·검지너클·새끼너클 세 점의 외적으로 구합니다. 이 세 숫자가 수향을 담습니다.

**`PoseFeature+Angles.swift`** — 수향을 담는 세 숫자

```swift, highlight=[7, 8, 9, 10, 11, 12, 13, 14]
import ARKit
import simd

extension PoseFeature {
    // …

    /// 손바닥 법선은 손목·검지너클·새끼너클 세 점의 외적으로 구한다.
    static func palmNormal(_ local: JointReader) -> SIMD3<Float> {
        let index = local(.indexFingerKnuckle)
        let little = local(.littleFingerKnuckle)
        let n = cross(index, little)
        let len = length(n)
        return len > 1e-5 ? n / len : SIMD3(0, 0, 1)
    }
}
```

### 2.5

**굽힘 15개는 손가락마다 3개씩 뽑습니다.** 관절 사슬을 손가락별로 미리 적어 두고, 앞에서 만든 `jointAngle`을 세 번씩 돌립니다. 화면에 22개 숫자를 세 덩어리로 찍어 보면 — 손을 움직일 때 굽힘값이 따라 움직이고, 손을 돌릴 때 법선이 바뀌어야 합니다.

**`PoseFeature+Angles.swift`** — 손가락 5개 × 관절 3개 = 15

```swift, highlight=[7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
import ARKit
import simd

extension PoseFeature {
    // …

    /// 손가락마다 3개씩, 뿌리에서 끝 방향으로 열다섯 개.
    static func bendAngles(_ local: JointReader) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(bendCount)
        for chain in jointChains {
            for i in 0..<3 {
                out.append(jointAngle(local(chain[i]), local(chain[i + 1]), local(chain[i + 2])))
            }
        }
        return out
    }

    /// [뿌리, 너클, 중간뿌리, 중간끝, 끝] 5개씩 × 5손가락.
    /// 앞 세 점으로 첫 굽힘각을 재기 위해 뿌리 관절을 하나 더 앞에 둔다.
    static let jointChains: [[HandSkeleton.JointName]] = [
        [.wrist, .thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip],
        [.indexFingerMetacarpal, .indexFingerKnuckle, .indexFingerIntermediateBase,
         .indexFingerIntermediateTip, .indexFingerTip],
        [.middleFingerMetacarpal, .middleFingerKnuckle, .middleFingerIntermediateBase,
         .middleFingerIntermediateTip, .middleFingerTip],
        [.ringFingerMetacarpal, .ringFingerKnuckle, .ringFingerIntermediateBase,
         .ringFingerIntermediateTip, .ringFingerTip],
        [.littleFingerMetacarpal, .littleFingerKnuckle, .littleFingerIntermediateBase,
         .littleFingerIntermediateTip, .littleFingerTip]
    ]
}
```

### 실행 결과

**2단계를 마치면 나오는 화면**

![2단계 실행 화면](step2.jpg)

*visionOS 26.2 시뮬레이터에서 직접 캡처*

### 체크포인트

#### 여기까지 하면

- 굽힘 15개, 벌림 4개, 법선 3개가 모두 표시된다
- 합계가 22차원이라고 뜬다

#### 안 되면 확인할 것

- `.xyz`는 simd에 기본으로 없습니다. `SIMD4` 확장을 직접 만들어야 합니다 (`PoseFeature.swift` 맨 위에 있습니다).
- 값이 전부 0이면 손목 관절이 추적되지 않은 것입니다. `isTracked`를 확인하세요.
- `Cannot find 'dot' in scope` — `import simd`가 빠졌습니다.

### 계속하기

- <doc:JihwaTutor>
- <doc:Step-3-Reference-Poses>
