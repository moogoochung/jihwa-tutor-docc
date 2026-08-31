import ARKit
import simd
import OSLog
import QuartzCore

/// 실기기 경로. 손 스켈레톤 추적은 몰입 공간에서만 동작한다.
///
/// 관절 좌표와 카메라 프레임은 기기 밖으로 내보내지 않는다.
/// 파일 · 로그 · 네트워크 · 분석 도구 어디에도 남기지 않는다.
@MainActor
final class HandTrackingFeed: HandFeed {
    private let session = ARKitSession()
    private let provider = HandTrackingProvider()
    private let logger = Logger(subsystem: "JihwaTutor", category: "HandTracking")

    private var continuation: AsyncStream<HandSample>.Continuation?
    private var task: Task<Void, Never>?

    /// 주로 쓰는 손. 설정에서 고를 수 있다.
    var preferredChirality: HandAnchor.Chirality = .right

    let samples: AsyncStream<HandSample>

    init() {
        var cont: AsyncStream<HandSample>.Continuation!
        samples = AsyncStream { cont = $0 }
        continuation = cont
    }

    static var isSupported: Bool { HandTrackingProvider.isSupported }

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

    func stop() {
        task?.cancel()
        task = nil
        session.stop()
        continuation?.finish()
    }

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
