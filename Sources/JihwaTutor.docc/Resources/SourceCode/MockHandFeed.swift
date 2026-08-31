import ARKit
import Foundation
import QuartzCore
import simd

/// 시뮬레이터 경로. 손 스켈레톤 앵커가 오지 않으므로 특징 벡터를 직접 재생한다.
///
/// 1단계에서 이 경로를 함께 만들어 두면 개발 속도가 크게 달라진다.
/// 실기기 없이도 판정 · 안정화 · 피드백 전체를 돌려 볼 수 있다.
@MainActor
final class MockHandFeed: HandFeed {
    private var continuation: AsyncStream<HandSample>.Continuation?
    private var task: Task<Void, Never>?

    /// 재생할 목표 자모. 이 글자의 기준 포즈 주변에서 흔들리는 손을 흉내 낸다.
    var target: Jamo = .giyeok
    /// 일부러 실어 주는 오차(라디안). 0이면 정답, 크면 실패.
    var injectedError: Float = 0.35
    /// 프레임 주기. 90Hz.
    var interval: Duration = .milliseconds(11)

    let samples: AsyncStream<HandSample>

    init() {
        var cont: AsyncStream<HandSample>.Continuation!
        samples = AsyncStream { cont = $0 }
        continuation = cont
    }

    func start() async {
        task = Task { [weak self] in
            var phase: Float = 0
            while !Task.isCancelled {
                guard let self else { return }
                if let base = ReferenceLibrary.shared.reference(for: self.target) {
                    self.continuation?.yield(self.perturb(base, phase: phase))
                }
                phase += 0.05
                try? await Task.sleep(for: self.interval)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        continuation?.finish()
    }

    /// 중지 하나에 오차를 싣고, 나머지는 사람 손 떨림 수준으로만 흔든다.
    private func perturb(_ base: PoseFeature, phase: Float) -> HandSample {
        var bend = base.bend
        let jitter: Float = 0.02
        for i in bend.indices { bend[i] += sin(phase + Float(i)) * jitter }
        if bend.count > 6 { bend[7] += injectedError }   // 중지 중간 관절

        let f = PoseFeature(bend: bend, spread: base.spread, palmNormal: base.palmNormal)
        return HandSample(feature: f,
                          chirality: .right,
                          wristTransform: nil,
                          handSpan: 0.09,
                          timestamp: CACurrentMediaTime())
    }
}
