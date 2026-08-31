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

struct PoseMatcher: Sendable {
    /// 굽힘각 허용 오차. 15도. 이보다 빡빡하면 초심자가 한 글자도 통과하지 못한다.
    var bendTolerance: Float = 0.26
    /// 수향 허용 오차. 25도. 손목은 굽힘각보다 재현성이 낮다.
    var orientationTolerance: Float = 0.44
    /// 약지와 새끼를 서로 다르게 접어야 하는 글자에서 그 두 손가락에만 곱하는 허용 오차 배수.
    ///
    /// 두 손가락은 깊은손가락굽힘근의 힘줄을 나눠 쓰기 때문에 완전히 분리되지 않는다.
    /// 되는 사람도 있고 안 되는 사람도 있으며, 안 되는 사람은 손가락이 부들부들 떨린다.
    /// 실제 지화 교육에서도 이런 글자는 대강 모양만 맞으면 인정한다.
    /// 기계가 사람보다 엄격하면 배우는 사람이 지친다.
    var coupledFingerRelief: Float = 2

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

    /// 40자 전체와 비교해 가장 가까운 순으로 돌려준다. 프레임당 1ms 예산 안에 든다.
    @MainActor
    func rank(_ feature: PoseFeature, in library: ReferenceLibrary) -> [PoseMatch] {
        library.all()
            .map { match(feature, to: $0.value, jamo: $0.key) }
            .sorted { $0.distance < $1.distance }
    }
}
