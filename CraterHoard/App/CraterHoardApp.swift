import SwiftUI

@main
struct CraterHoardApp: App {
    private let bootstrap: Result<AppDependencies, Error>

    init() {
        bootstrap = Result { try AppDependencies() }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let dependencies):
                RootView(dependencies: dependencies)
            case .failure(let error):
                StartupErrorView(message: error.localizedDescription)
            }
        }
    }
}

/// Shown only if the local database cannot be opened, which should never happen in practice.
struct StartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.Colors.basalt.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.Colors.lava)
                    .accessibilityHidden(true)
                Text("The vault door is stuck")
                    .font(.display(24))
                    .foregroundStyle(Theme.Colors.paper)
                Text("Crater Hoard could not open its save data. Please restart the app. If the problem persists, reinstalling creates a fresh save.")
                    .font(.body(16))
                    .foregroundStyle(Theme.Colors.paper.opacity(0.85))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.Colors.paper.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(32)
            .frame(maxWidth: 480)
        }
        .preferredColorScheme(.dark)
    }
}
