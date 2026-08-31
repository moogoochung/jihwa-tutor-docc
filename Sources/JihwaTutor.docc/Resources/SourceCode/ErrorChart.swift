import SwiftUI

/// 손가락별 오차와 허용 오차선. 색이 아니라 길이와 형태로 구분한다.
struct ErrorChart: View {
    @Environment(TutorModel.self) private var model

    var body: some View {
        GroupBox("기준 포즈 대비 손가락별 오차") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(FingerName.allCases, id: \.rawValue) { finger in
                    row(finger)
                }
                Text("허용 오차 \(Int(model.toleranceDegrees))° · 오차가 가장 큰 손가락 하나만 교정 문장으로 만듭니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let note = model.fingerNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func row(_ finger: FingerName) -> some View {
        let degrees = worstDegrees(finger)
        let tolerance = toleranceDegrees(finger)
        let relaxed = tolerance > CGFloat(model.toleranceDegrees) + 0.5
        let over = degrees > tolerance
        return HStack(spacing: 12) {
            Text(finger.korean)
                .font(.callout)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                let full = geo.size.width
                let unit: CGFloat = full / 45.0     // 0…45도 눈금
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 10)
                    Capsule()
                        .fill(over ? Color.orange : Color.green)
                        .frame(width: min(degrees * unit, full), height: 10)
                    Rectangle()
                        .fill(.primary.opacity(0.5))
                        .frame(width: 1.5, height: 18)
                        .offset(x: tolerance * unit)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("\(Int(degrees))°")
                .font(.caption.monospacedDigit())
                .frame(width: 40, alignment: .trailing)

            Text(over ? "초과" : (relaxed ? "완화" : "통과"))
                .font(.caption2)
                .frame(width: 34)
                .foregroundStyle(over ? .orange : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(finger.korean) 오차 \(Int(degrees))도, 허용 오차 \(Int(tolerance))도, \(over ? "초과" : "통과")")
    }

    /// 손가락마다 허용 오차가 다를 수 있다.
    /// 약지와 새끼를 따로 접어야 하는 글자에서는 그 둘만 넓다.
    private func toleranceDegrees(_ finger: FingerName) -> CGFloat {
        guard let t = model.currentMatch?.bendTolerance,
              t.count == PoseFeature.bendCount else { return CGFloat(model.toleranceDegrees) }
        return CGFloat(t[finger.rawValue * 3] * 180 / .pi)
    }

    /// 손가락 하나에 관절 3개. 그중 가장 큰 오차를 대표값으로 쓴다.
    private func worstDegrees(_ finger: FingerName) -> CGFloat {
        guard let errors = model.currentMatch?.bendError,
              errors.count == PoseFeature.bendCount else { return 0 }
        let slice = errors[(finger.rawValue * 3)..<(finger.rawValue * 3 + 3)]
        return CGFloat((slice.max() ?? 0) * 180 / .pi)
    }
}
