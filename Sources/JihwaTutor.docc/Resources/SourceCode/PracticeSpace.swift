import RealityKit
import SwiftUI

/// 손 스켈레톤 추적은 몰입 공간에서만 동작한다.
struct PracticeSpace: View {
    @Environment(TutorModel.self) private var model

    var body: some View {
        RealityView { content in
            content.add(model.overlay.root)
        }
        .task {
            await model.start()
        }
        .onDisappear {
            model.stop()
        }
    }
}
