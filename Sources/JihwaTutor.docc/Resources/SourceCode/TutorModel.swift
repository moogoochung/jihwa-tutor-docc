import ARKit
import Observation
import SwiftUI

/// 인식 → 피드백 → 오버레이 루프를 한 자리에 묶는다.
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

    /// 주로 쓰는 손.
    var handedness: HandAnchor.Chirality = .right {
        didSet { liveFeed.preferredChirality = handedness }
    }

    /// 겹쳐 보기 / 나란히 보기. 초심자는 나란히, 교정 단계에서는 겹치는 쪽을 선호한다.
    var overlayMode: GuideOverlay.Mode = .sideBySide

    /// 실기기가 아니면 목 데이터로 자동 전환한다.
    private(set) var usingMockData = false
    private(set) var isRunning = false

    // 판정 결과
    private(set) var currentMatch: PoseMatch?
    private(set) var bestGuess: PoseMatch?
    private(set) var advice: String?
    /// 이 글자가 약지·새끼를 관대하게 본다는 안내. 해당 없으면 nil.
    private(set) var fingerNote: String?
    private(set) var confirmed: Jamo?
    private(set) var holdProgress: Double = 0
    /// 특징 추출 + 40자 비교에 걸린 시간(ms). 프레임당 1ms 예산을 확인한다.
    private(set) var lastFrameCost: Double = 0

    var matcher = PoseMatcher()
    var coach = Coach()
    let stabilizer = Stabilizer()
    let overlay = GuideOverlay()

    private let liveFeed = HandTrackingFeed()
    private let mockFeed = MockHandFeed()
    private var pump: Task<Void, Never>?

    /// 허용 오차는 감으로 정하지 않는다. 숙련자 표준편차의 두 배에서 출발해
    /// 초심자 통과율을 보며 조정한다. 이 슬라이더는 그 조정용이다.
    var toleranceDegrees: Double {
        get { Double(matcher.bendTolerance) * 180 / .pi }
        set {
            let radians = Float(newValue * .pi / 180)
            matcher.bendTolerance = radians
            coach.bendTolerance = radians
        }
    }

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        if HandTrackingFeed.isSupported {
            usingMockData = false
            liveFeed.preferredChirality = handedness
            await liveFeed.start()
            pump = Task { [weak self] in
                guard let self else { return }
                for await sample in self.liveFeed.samples { self.consume(sample) }
            }
        } else {
            usingMockData = true
            mockFeed.target = target
            await mockFeed.start()
            pump = Task { [weak self] in
                guard let self else { return }
                for await sample in self.mockFeed.samples { self.consume(sample) }
            }
        }
    }

    func stop() {
        pump?.cancel()
        pump = nil
        liveFeed.stop()
        mockFeed.stop()
        isRunning = false
    }

    /// 목 데이터에 실어 주는 오차. 슬라이더로 조절해 판정을 시험한다.
    func setMockError(_ radians: Float) { mockFeed.injectedError = radians }

    // MARK: - 루프

    private func consume(_ sample: HandSample) {
        let t0 = CFAbsoluteTimeGetCurrent()

        guard let reference = ReferenceLibrary.shared.reference(for: target) else { return }
        let match = matcher.match(sample.feature, to: reference, jamo: target)

        // 목표와 다른 글자를 짚고 있으면 그것도 알려 준다.
        let ranked = matcher.rank(sample.feature, in: ReferenceLibrary.shared)

        stabilizer.feed(match, at: sample.timestamp)

        currentMatch = match
        bestGuess = ranked.first
        advice = coach.advice(for: match)
        fingerNote = coach.note(for: match)
        confirmed = stabilizer.confirmed
        holdProgress = stabilizer.progress

        overlay.update(match: match,
                       reference: reference,
                       wrist: sample.wristTransform,
                       span: sample.handSpan,
                       tolerances: match.bendTolerance,
                       mode: overlayMode)

        lastFrameCost = (CFAbsoluteTimeGetCurrent() - t0) * 1000
    }
}
