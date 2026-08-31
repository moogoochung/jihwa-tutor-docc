import ARKit
import SwiftUI

struct TutorView: View {
    @Environment(TutorModel.self) private var model
    @Environment(\.openImmersiveSpace) private var openSpace
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @State private var spaceOpen = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    JamoPicker(selection: $model.target)
                    VerdictCard()
                    ErrorChart()
                    settings
                }
                .padding(28)
            }
            .navigationTitle("지화 튜터")
            .toolbar {
                ToolbarItem(placement: .bottomOrnament) {
                    Button(spaceOpen ? "연습 끝내기" : "연습 시작") {
                        Task { await toggleSpace() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("손으로 지문자를 만들면 어느 손가락이 얼마나 어긋났는지 짚어 줍니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
            if model.usingMockData {
                Label("실기기가 아니어서 목 데이터를 재생 중입니다. 판정 로직은 그대로 돌아갑니다.",
                      systemImage: "waveform.path")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if ReferenceLibrary.shared.isPlaceholder(model.target) {
                Label("이 글자의 기준 포즈는 아직 자리표시자입니다. 숙련자 포즈로 교체해야 합니다.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            if confusableCount > 0 {
                Label("현재 기준 표에서 서로 갈라내지 못하는 자모 쌍이 \(confusableCount)개 있습니다. 실측 포즈로 교체하면 줄어듭니다.",
                      systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settings: some View {
        @Bindable var model = model
        return GroupBox("설정") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("주로 쓰는 손", selection: $model.handedness) {
                    Text("오른손").tag(ARKitChirality.right)
                    Text("왼손").tag(ARKitChirality.left)
                }
                .pickerStyle(.segmented)

                Picker("가이드", selection: $model.overlayMode) {
                    ForEach(GuideOverlay.Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading) {
                    Text("허용 오차 \(Int(model.toleranceDegrees))°")
                        .font(.caption)
                    Slider(value: $model.toleranceDegrees, in: 5...30, step: 1)
                }

                if model.usingMockData {
                    MockErrorSlider()
                }

                Text("프레임당 판정 비용 \(model.lastFrameCost, format: .number.precision(.fractionLength(2)))ms · 예산 1ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }

    private var confusableCount: Int {
        ReferenceLibrary.shared.confusablePairs().count
    }

    private func toggleSpace() async {
        if spaceOpen {
            await dismissSpace()
            spaceOpen = false
        } else {
            if case .opened = await openSpace(id: "practice") { spaceOpen = true }
        }
    }
}

private struct MockErrorSlider: View {
    @Environment(TutorModel.self) private var model
    @State private var degrees: Double = 20

    var body: some View {
        VStack(alignment: .leading) {
            Text("목 데이터 오차 \(Int(degrees))° (중지)")
                .font(.caption)
            Slider(value: $degrees, in: 0...45, step: 1)
                .onChange(of: degrees) { _, new in
                    model.setMockError(Float(new * .pi / 180))
                }
        }
    }
}
