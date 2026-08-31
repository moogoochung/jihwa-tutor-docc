import Foundation
import simd

/// 자모 하나의 기준 포즈를 사람이 읽고 쓸 수 있는 형태로 적은 것.
/// curl 0 = 완전히 편 상태, 1 = 완전히 접은 상태.
struct PoseRecipe: Sendable {
    var curl: [Float]              // 손가락 5개
    var spread: [Float]            // 인접 4쌍, 0 = 붙임, 1 = 최대로 벌림
    var palm: SIMD3<Float>         // 손목 기준 손바닥 법선

    func feature() -> PoseFeature {
        // 손가락 하나의 굽힘은 뿌리·중간·끝에 각각 다르게 실린다.
        let weight: [Float] = [0.9, 1.1, 1.0]
        let maxBend: Float = 1.5   // 라디안. 완전히 접은 관절의 굽힘각.
        var bend: [Float] = []
        for c in curl {
            for w in weight { bend.append(clampf(c, 0, 1) * maxBend * w) }
        }
        let maxSpread: Float = 0.45
        return PoseFeature(bend: bend,
                           spread: spread.map { clampf($0, 0, 1) * maxSpread },
                           palmNormal: normalize(palm))
    }
}

/// 기준 포즈 표. 40자를 여기에 채운다.
///
/// ⚠️ 아래 값은 문서의 구조를 그대로 옮긴 자리표시자다.
/// 실제 손 모양은 국립국어원 한국수어사전에서 확인하고,
/// 숙련자 포즈를 여러 번 기록해 평균 특징 벡터로 교체해야 한다.
/// 잘못 배운 손 모양을 가르치는 앱은 없느니만 못하다.
@MainActor
final class ReferenceLibrary {
    static let shared = ReferenceLibrary()

    private(set) var table: [Jamo: PoseFeature] = [:]
    /// 실측으로 교체된 자모. 자리표시자와 구분한다.
    private(set) var measured: Set<Jamo> = []

    init() {
        for (jamo, recipe) in Self.placeholders {
            table[jamo] = recipe.feature()
        }
    }

    func all() -> [(key: Jamo, value: PoseFeature)] {
        table.map { (key: $0.key, value: $0.value) }
    }

    func reference(for jamo: Jamo) -> PoseFeature? { table[jamo] }
    func isPlaceholder(_ jamo: Jamo) -> Bool { !measured.contains(jamo) }

    /// 숙련자 포즈 여러 벌을 평균 내 기준 포즈로 등록한다.
    /// 관절별 표준편차가 곧 초기 허용 오차가 된다.
    @discardableResult
    func register(_ jamo: Jamo, samples: [PoseFeature]) -> (mean: PoseFeature, stdDev: [Float])? {
        guard !samples.isEmpty else { return nil }
        let n = Float(samples.count)

        var bend = [Float](repeating: 0, count: PoseFeature.bendCount)
        var spread = [Float](repeating: 0, count: PoseFeature.spreadCount)
        var palm = SIMD3<Float>.zero
        for s in samples {
            for i in 0..<PoseFeature.bendCount { bend[i] += s.bend[i] }
            for i in 0..<PoseFeature.spreadCount { spread[i] += s.spread[i] }
            palm += s.palmNormal
        }
        bend = bend.map { $0 / n }
        spread = spread.map { $0 / n }
        palm = length(palm) > 1e-5 ? normalize(palm) : SIMD3(0, 0, 1)

        let stdDev = (0..<PoseFeature.bendCount).map { i -> Float in
            let v = samples.reduce(Float(0)) { $0 + pow($1.bend[i] - bend[i], 2) } / n
            return sqrt(v)
        }

        let mean = PoseFeature(bend: bend, spread: spread, palmNormal: palm)
        table[jamo] = mean
        measured.insert(jamo)
        confusableCache = nil
        return (mean, stdDev)
    }

    // MARK: - 혼동 쌍 감사

    /// 기준 표 안에서 서로 너무 가까운 자모 쌍을 찾는다.
    /// 거리가 1 미만이면 그 두 글자는 현재 표로는 갈라낼 수 없다.
    /// 4단계에서 이 목록에만 CoreML 보조 분류기를 붙인다.
    /// 매 프레임 다시 세지 않도록 캐시한다. 기준 표가 바뀌면 무효화된다.
    private var confusableCache: [(Jamo, Jamo, Float)]?

    func confusablePairs(threshold: Float = 1, matcher: PoseMatcher = PoseMatcher())
        -> [(Jamo, Jamo, Float)] {
        if threshold == 1, let cached = confusableCache { return cached }
        let items = all().sorted { $0.key.rawValue < $1.key.rawValue }
        var out: [(Jamo, Jamo, Float)] = []
        for i in items.indices {
            for j in (i + 1)..<items.count {
                let d = matcher.match(items[i].value, to: items[j].value, jamo: items[j].key).distance
                if d < threshold { out.append((items[i].key, items[j].key, d)) }
            }
        }
        let sorted = out.sorted { $0.2 < $1.2 }
        if threshold == 1 { confusableCache = sorted }
        return sorted
    }

    // MARK: - 자리표시자 표

    static let placeholders: [Jamo: PoseRecipe] = {
        let up = SIMD3<Float>(0, 1, 0)
        let out = SIMD3<Float>(0, 0, 1)
        let down = SIMD3<Float>(0, -1, 0)
        let side = SIMD3<Float>(1, 0, 0)

        func r(_ curl: [Float], _ spread: [Float] = [0.3, 0.2, 0.2, 0.2],
               _ palm: SIMD3<Float> = out) -> PoseRecipe {
            PoseRecipe(curl: curl, spread: spread, palm: palm)
        }

        return [
            // 자음 19
            .giyeok:      r([0.2, 0.1, 0.9, 0.9, 0.9]),
            .ssangGiyeok: r([0.2, 0.1, 0.1, 0.9, 0.9]),
            .nieun:       r([0.8, 0.2, 0.9, 0.9, 0.9]),
            .digeut:      r([0.3, 0.3, 0.3, 0.3, 0.3], [0.1, 0.1, 0.1, 0.1]),
            .ssangDigeut: r([0.3, 0.3, 0.3, 0.3, 0.9], [0.1, 0.1, 0.1, 0.1]),
            .rieul:       r([0.9, 0.1, 0.1, 0.9, 0.9]),
            .mieum:       r([0.9, 0.9, 0.9, 0.9, 0.9], [0.0, 0.0, 0.0, 0.0]),
            .bieup:       r([0.1, 0.1, 0.1, 0.1, 0.1], [0.6, 0.4, 0.4, 0.4]),
            .ssangBieup:  r([0.1, 0.1, 0.1, 0.1, 0.9], [0.6, 0.4, 0.4, 0.4]),
            .siot:        r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.7, 0.2, 0.2]),
            .ssangSiot:   r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.7, 0.2, 0.2], down),
            .ieung:       r([0.5, 0.5, 0.5, 0.5, 0.5], [0.0, 0.0, 0.0, 0.0]),
            .jieut:       r([0.5, 0.5, 0.1, 0.9, 0.9]),
            .ssangJieut:  r([0.5, 0.5, 0.1, 0.1, 0.9]),
            .chieut:      r([0.5, 0.1, 0.1, 0.5, 0.9], [0.3, 0.5, 0.2, 0.2]),
            .kieuk:       r([0.2, 0.1, 0.5, 0.9, 0.9]),
            .tieut:       r([0.2, 0.1, 0.1, 0.5, 0.9]),
            .pieup:       r([0.2, 0.1, 0.1, 0.1, 0.9], [0.4, 0.3, 0.3, 0.3]),
            .hieut:       r([0.9, 0.1, 0.9, 0.9, 0.9], [0.4, 0.2, 0.2, 0.2]),

            // 모음 21
            .a:    r([0.1, 0.1, 0.9, 0.9, 0.9], [0.6, 0.2, 0.2, 0.2]),
            .ae:   r([0.1, 0.1, 0.1, 0.9, 0.9], [0.6, 0.5, 0.2, 0.2]),
            .ya:   r([0.1, 0.1, 0.1, 0.9, 0.9], [0.6, 0.2, 0.2, 0.2]),
            .yae:  r([0.1, 0.1, 0.1, 0.1, 0.9], [0.6, 0.3, 0.3, 0.2]),
            .eo:   r([0.5, 0.1, 0.9, 0.9, 0.9], [0.4, 0.2, 0.2, 0.2]),
            .e:    r([0.5, 0.1, 0.1, 0.9, 0.9], [0.4, 0.4, 0.2, 0.2]),
            .yeo:  r([0.5, 0.1, 0.1, 0.9, 0.9], [0.4, 0.2, 0.2, 0.2]),
            .ye:   r([0.5, 0.1, 0.1, 0.1, 0.9], [0.4, 0.3, 0.3, 0.2]),
            .o:    r([0.9, 0.1, 0.9, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], up),
            .wa:   r([0.9, 0.1, 0.9, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], side),
            .wae:  r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.4, 0.2, 0.2], side),
            .oe:   r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], side),
            .yo:   r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], up),
            .u:    r([0.9, 0.1, 0.9, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], down),
            .weo:  r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.3, 0.2, 0.2], down),
            .we:   r([0.9, 0.1, 0.1, 0.1, 0.9], [0.2, 0.3, 0.3, 0.2], down),
            .wi:   r([0.5, 0.1, 0.1, 0.1, 0.1], [0.3, 0.3, 0.3, 0.3], down),
            .yu:   r([0.9, 0.1, 0.1, 0.1, 0.9], [0.2, 0.3, 0.3, 0.2], up),
            .eu:   r([0.9, 0.1, 0.9, 0.9, 0.9], [0.2, 0.2, 0.2, 0.2], out),
            .ui:   r([0.9, 0.1, 0.1, 0.9, 0.9], [0.2, 0.3, 0.2, 0.2], out),
            .i:    r([0.9, 0.9, 0.9, 0.9, 0.1], [0.2, 0.2, 0.2, 0.4], side)
        ]
    }()
}
