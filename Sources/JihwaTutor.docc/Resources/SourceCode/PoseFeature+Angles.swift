import ARKit
import simd

typealias JointReader = (HandSkeleton.JointName) -> SIMD3<Float>

/// 세 관절이 이루는 굽힘각. 편 손가락은 0에 가깝다.
func jointAngle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
    let u = a - b, v = c - b
    let lu = length(u), lv = length(v)
    guard lu > 1e-5, lv > 1e-5 else { return 0 }   // 0으로 나누기 방지
    return .pi - acos(clampf(dot(u, v) / (lu * lv), -1, 1))
}

extension PoseFeature {

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

    /// 인접한 손가락 방향 벡터 사이의 각. 네 개.
    static func spreadAngles(_ local: JointReader) -> [Float] {
        let dirs = jointChains.map { chain -> SIMD3<Float> in
            let root = local(chain[1])          // knuckle
            let tip = local(chain[4])           // tip
            let d = tip - root
            let l = length(d)
            return l > 1e-5 ? d / l : SIMD3(0, 1, 0)
        }
        return (0..<4).map { acos(clampf(dot(dirs[$0], dirs[$0 + 1]), -1, 1)) }
    }

    /// 손바닥 법선은 손목·검지너클·새끼너클 세 점의 외적으로 구한다.
    static func palmNormal(_ local: JointReader) -> SIMD3<Float> {
        let index = local(.indexFingerKnuckle)
        let little = local(.littleFingerKnuckle)
        let n = cross(index, little)
        let len = length(n)
        return len > 1e-5 ? n / len : SIMD3(0, 0, 1)
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
