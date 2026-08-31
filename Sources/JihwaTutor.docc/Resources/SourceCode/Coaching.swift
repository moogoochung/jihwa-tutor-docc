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

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
