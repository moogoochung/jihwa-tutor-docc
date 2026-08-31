import SwiftUI

/// 자음 19 · 모음 21. 학습 순서대로 한 글자씩 고른다.
struct JamoPicker: View {
    @Binding var selection: Jamo

    private let columns = Array(repeating: GridItem(.flexible(minimum: 44), spacing: 8), count: 10)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("자음 19", Jamo.consonants)
            section("모음 21", Jamo.vowels)
        }
    }

    private func section(_ title: String, _ items: [Jamo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { jamo in
                    Button {
                        selection = jamo
                    } label: {
                        Text(jamo.rawValue)
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .overlay(alignment: .topTrailing) {
                                if jamo.isOrientationCritical {
                                    Circle()
                                        .frame(width: 5, height: 5)
                                        .foregroundStyle(.tint)
                                        .padding(4)
                                }
                            }
                    }
                    .buttonStyle(.bordered)
                    .background(jamo == selection ? Color.accentColor.opacity(0.35) : .clear,
                                in: .rect(cornerRadius: 12))
                }
            }
            Text("점이 붙은 글자는 손바닥 방향으로 갈립니다. 회전 정규화를 적용하면 서로 구별할 수 없게 됩니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
