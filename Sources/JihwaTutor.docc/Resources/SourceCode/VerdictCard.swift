import SwiftUI

/// 판정과 교정 문장. 한 번에 하나만 말한다.
struct VerdictCard: View {
    @Environment(TutorModel.self) private var model

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: model.holdProgress)
                        .stroke(passed ? Color.green : Color.orange,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(model.target.rawValue).font(.system(size: 44, weight: .semibold))
                }
                .frame(width: 110, height: 110)
                .animation(.linear(duration: 0.1), value: model.holdProgress)

                VStack(alignment: .leading, spacing: 8) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(passed ? .green : .primary)

                    if let advice = model.advice {
                        Label(advice, systemImage: "hand.point.up.left")
                            .font(.body)
                    }

                    if let note = model.fingerNote, !passed {
                        Label(note, systemImage: "hand.raised.fingers.spread")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let best = model.bestGuess, best.jamo != model.target, !passed {
                        Text("지금 손 모양은 ‘\(best.jamo.rawValue)’에 더 가깝습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let m = model.currentMatch {
                        Text("거리 \(m.distance, format: .number.precision(.fractionLength(2))) · 수향 오차 \(Int(m.orientationError * 180 / .pi))°")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(headline + (model.advice.map { ". " + $0 } ?? "")))
        }
    }

    private var passed: Bool { model.confirmed == model.target }

    private var headline: String {
        if passed { return "통과" }
        if model.currentMatch == nil { return "손을 보여 주세요" }
        if model.currentMatch?.passed == true { return "유지하세요" }
        return "조금 더"
    }
}
