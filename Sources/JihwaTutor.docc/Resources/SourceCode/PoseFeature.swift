import ARKit
import simd

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

@inlinable
func clampf(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }

/// 지화 한 글자를 판별하는 데 쓰는 22차원 특징.
///
/// 정규화는 위치와 손 크기까지만 한다. 회전까지 정규화하면
/// 손바닥 방향으로 갈리는 7자(ㅆ · 모음 6자)를 잃는다.
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

    init(bend: [Float], spread: [Float], palmNormal: SIMD3<Float>) {
        self.bend = bend
        self.spread = spread
        self.palmNormal = palmNormal
    }

    var isWellFormed: Bool {
        bend.count == Self.bendCount && spread.count == Self.spreadCount
    }

    // MARK: - 추출

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
