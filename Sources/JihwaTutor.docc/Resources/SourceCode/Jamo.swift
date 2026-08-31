import Foundation

/// 한글 지문자 자모. 한국수화사전(2005) 기준 자음 19자 · 모음 21자 = 40자.
enum Jamo: String, CaseIterable, Identifiable, Sendable {
    // 자음 19
    case giyeok = "ㄱ", ssangGiyeok = "ㄲ", nieun = "ㄴ", digeut = "ㄷ", ssangDigeut = "ㄸ"
    case rieul = "ㄹ", mieum = "ㅁ", bieup = "ㅂ", ssangBieup = "ㅃ", siot = "ㅅ"
    case ssangSiot = "ㅆ", ieung = "ㅇ", jieut = "ㅈ", ssangJieut = "ㅉ", chieut = "ㅊ"
    case kieuk = "ㅋ", tieut = "ㅌ", pieup = "ㅍ", hieut = "ㅎ"

    // 모음 21
    case a = "ㅏ", ae = "ㅐ", ya = "ㅑ", yae = "ㅒ", eo = "ㅓ", e = "ㅔ", yeo = "ㅕ", ye = "ㅖ"
    case o = "ㅗ", wa = "ㅘ", wae = "ㅙ", oe = "ㅚ", yo = "ㅛ"
    case u = "ㅜ", weo = "ㅝ", we = "ㅞ", wi = "ㅟ", yu = "ㅠ"
    case eu = "ㅡ", ui = "ㅢ", i = "ㅣ"

    var id: String { rawValue }
    var character: Character { rawValue.first! }

    var isConsonant: Bool { Jamo.consonants.contains(self) }

    static let consonants: [Jamo] = [
        .giyeok, .ssangGiyeok, .nieun, .digeut, .ssangDigeut, .rieul, .mieum,
        .bieup, .ssangBieup, .siot, .ssangSiot, .ieung, .jieut, .ssangJieut,
        .chieut, .kieuk, .tieut, .pieup, .hieut
    ]

    static let vowels: [Jamo] = [
        .a, .ae, .ya, .yae, .eo, .e, .yeo, .ye, .o, .wa, .wae, .oe, .yo,
        .u, .weo, .we, .wi, .yu, .eu, .ui, .i
    ]

    /// 손 모양이 같고 손바닥 방향으로만 갈리는 자모.
    /// 회전 정규화를 적용하면 이 글자들이 서로 뭉개진다.
    /// 표준 손 모양은 국립국어원 한국수어사전에서 반드시 재확인할 것.
    static let orientationCritical: Set<Jamo> = [.ssangSiot, .o, .yo, .u, .yu, .eu, .i]

    var isOrientationCritical: Bool { Jamo.orientationCritical.contains(self) }
}

/// 굽힘각 인덱스(0..<15)를 손가락으로 되돌린다.
enum FingerName: Int, CaseIterable, Sendable {
    case thumb, index, middle, ring, little

    var korean: String {
        switch self {
        case .thumb:  "엄지"
        case .index:  "검지"
        case .middle: "중지"
        case .ring:   "약지"
        case .little: "새끼"
        }
    }
}
