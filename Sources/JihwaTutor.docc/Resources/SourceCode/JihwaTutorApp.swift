import SwiftUI

@main
struct JihwaTutorApp: App {

    @State private var model = TutorModel()

    var body: some Scene {
        WindowGroup(id: "tutor") {
            TutorView()
                .environment(model)
        }
        .defaultSize(width: 720, height: 900)

        ImmersiveSpace(id: "practice") {
            PracticeSpace()
                .environment(model)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
