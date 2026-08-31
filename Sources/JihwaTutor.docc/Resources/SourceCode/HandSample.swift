import ARKit
import simd

/// 판정 단계로 넘어가는 한 프레임 분량의 손 정보.
/// 실기기 경로와 목 데이터 경로가 같은 타입을 낸다.
struct HandSample {
    var feature: PoseFeature
    var chirality: HandAnchor.Chirality
    /// 오버레이 정렬용. 목 데이터에서는 nil.
    var wristTransform: simd_float4x4?
    /// 손목에서 중지 너클까지의 거리. 오버레이 크기 보정에 쓴다.
    var handSpan: Float
    var timestamp: TimeInterval
}

@MainActor
protocol HandFeed: AnyObject {
    var samples: AsyncStream<HandSample> { get }
    func start() async
    func stop()
}

/// SwiftUI 쪽에서 ARKit 타입 이름을 짧게 쓰기 위한 별칭.
typealias ARKitChirality = HandAnchor.Chirality
