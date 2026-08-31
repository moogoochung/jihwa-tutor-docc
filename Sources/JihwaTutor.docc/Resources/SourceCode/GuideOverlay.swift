import UIKit
import RealityKit
import simd

/// 정답 손 모양을 반투명 뼈대로 사용자 손 위에 겹친다.
/// 정렬이 어긋나면 오버레이는 오히려 방해가 된다.
@MainActor
final class GuideOverlay {

    enum Mode: String, CaseIterable, Identifiable, Sendable {
        /// 손 옆에 나란히. 초심자가 선호한다.
        case sideBySide = "나란히"
        /// 정확히 겹치기. 교정 단계에서 선호한다.
        case overlaid = "겹치기"
        case hidden = "끄기"
        var id: String { rawValue }
    }

    let root = Entity()

    private var bones: [Entity] = []
    private var boneMesh: MeshResource = .generateBox(size: [0.008, 0.030, 0.008],
                                                     cornerRadius: 0.004)
    /// 손목 기준 뼈대 15개. 굽힘각 인덱스와 1:1로 맞춘다.
    private let boneCount = PoseFeature.bendCount

    init() {
        for i in 0..<boneCount {
            let e = Entity()
            e.name = "bone-\(i)"
            e.components.set(ModelComponent(mesh: boneMesh, materials: [Self.material(opacity: 0.15)]))
            // 손목 원점 기준 대략적인 손가락 배치. 기준 포즈 뼈대를 붙이면 교체된다.
            let finger = i / 3, joint = i % 3
            e.position = SIMD3(Float(finger - 2) * 0.022,
                               0.04 + Float(joint) * 0.030,
                               0)
            root.addChild(e)
            bones.append(e)
        }
        root.isEnabled = false
    }

    /// 손목을 원점, 손 크기를 1로 두고 만든 기준 뼈대를
    /// 사용자의 손목 변환과 손 크기로 되돌려 놓는다.
    func align(wrist: simd_float4x4, span: Float, mode: Mode) {
        var t = Transform(matrix: wrist)
        t.scale = SIMD3(repeating: max(span / 0.09, 0.5))
        if mode == .sideBySide {
            // 손 오른쪽 12cm 옆에 나란히 세운다.
            t.translation += SIMD3(0.12, 0, 0)
        }
        root.transform = t
    }

    /// 오차가 큰 관절만 불투명하게 만든다.
    /// 색을 하나 더 쓰는 대신 투명도로 구분해 색맹 사용자도 읽을 수 있게 한다.
    /// 관절마다 허용 오차가 다르다. 약지·새끼를 관대하게 보는 글자에서
    /// 그 두 손가락이 늘 진하게 보이면 사용자는 고칠 수 없는 것을 고치려 든다.
    func highlight(_ errors: [Float], tolerances: [Float]) {
        for (i, bone) in bones.enumerated() where i < errors.count {
            let tolerance = i < tolerances.count ? tolerances[i] : 0.26
            let over = min(errors[i] / max(tolerance, 1e-4), 2)
            bone.components.set(
                ModelComponent(mesh: boneMesh,
                               materials: [Self.material(opacity: 0.15 + 0.35 * over)])
            )
        }
    }

    func update(match: PoseMatch,
                reference: PoseFeature,
                wrist: simd_float4x4?,
                span: Float,
                tolerances: [Float],
                mode: Mode) {
        guard mode != .hidden, let wrist else {
            root.isEnabled = false
            return
        }
        root.isEnabled = true
        align(wrist: wrist, span: span, mode: mode)
        highlight(match.bendError, tolerances: tolerances)
    }

    private static func material(opacity: Float) -> UnlitMaterial {
        var m = UnlitMaterial(color: .white)
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return m
    }
}
