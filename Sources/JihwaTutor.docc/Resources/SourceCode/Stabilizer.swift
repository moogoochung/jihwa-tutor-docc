import Foundation

/// 프레임 단위 판정은 떨린다. 일정 시간 같은 글자가 유지되어야 확정한다.
@MainActor
final class Stabilizer {
    /// 이 시간 동안 유지되어야 통과. 짧으면 스쳐 지나가며 오답이 통과된다.
    var dwell: TimeInterval = 0.4
    /// 통과한 뒤에는 더 관대하게 본다. 손이 조금 흔들려도 풀리지 않게.
    var holdMultiplier: Float = 1.35

    private(set) var candidate: Jamo?
    private(set) var confirmed: Jamo?
    private var since: TimeInterval = 0

    /// 후보가 유지된 비율 0...1. 진행 링을 그리는 데 쓴다.
    private(set) var progress: Double = 0

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

    func reset() {
        candidate = nil
        confirmed = nil
        progress = 0
        since = 0
    }
}
