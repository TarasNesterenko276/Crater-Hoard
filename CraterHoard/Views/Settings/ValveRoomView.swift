import SwiftUI

/// Settings as valves on a pipe board: sound, haptics, replaying the guide and resetting progress.
struct ValveRoomView: View {
    @State private var viewModel: SettingsViewModel
    let onShowGuide: () -> Void

    init(viewModel: SettingsViewModel, onShowGuide: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onShowGuide = onShowGuide
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                valveToggle(
                    title: "Sound",
                    detail: "Clinks, sizzles and the low rumble of the lava.",
                    isOn: $viewModel.soundEnabled,
                    id: AccessibilityID.Settings.sound
                )
                valveToggle(
                    title: "Haptics",
                    detail: "Feel catches, bomb hits and lightning.",
                    isOn: $viewModel.hapticsEnabled,
                    id: AccessibilityID.Settings.haptics
                )

                Button(action: onShowGuide) {
                    HStack {
                        ArtImage("item_board").frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read the notice board")
                                .font(.display(17, relativeTo: .headline))
                            Text("All rules of the crater, one page each.")
                                .font(.body(14))
                                .foregroundStyle(Theme.Colors.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.body.bold())
                            .foregroundStyle(Theme.Colors.copperDark)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.paperShade.opacity(0.45)))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier(AccessibilityID.Settings.guide)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Danger valve")
                        .font(.display(17, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.danger)
                    Text("Empties the vault: gold, upgrades, keepers and every recorded shift.")
                        .font(.body(14))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(role: .destructive, action: viewModel.requestReset) {
                        Text("Reset progress")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CopperButtonStyle(tint: Theme.Colors.danger, isProminent: false))
                    .accessibilityIdentifier(AccessibilityID.Settings.reset)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.Colors.danger.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))

                Text("Crater Hoard \(viewModel.appVersion) · Plays fully offline · No ads, no purchases")
                    .font(.body(13, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
            .frame(maxWidth: Theme.Metrics.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("Reset all progress?", isPresented: $viewModel.isConfirmingReset, titleVisibility: .visible) {
            Button("Empty the vault", role: .destructive, action: viewModel.confirmReset)
                .accessibilityIdentifier(AccessibilityID.Settings.resetConfirm)
            Button("Keep my hoard", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .toast(message: $viewModel.toastMessage, isError: viewModel.toastIsError)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Settings.screen)
    }

    private func valveToggle(title: String, detail: String, isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                ArtImage("item_valve")
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(isOn.wrappedValue ? 90 : 0))
                    .animation(.spring(duration: 0.4), value: isOn.wrappedValue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.display(17, relativeTo: .headline))
                        .foregroundStyle(Theme.Colors.ink)
                    Text(detail)
                        .font(.body(14))
                        .foregroundStyle(Theme.Colors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.Colors.patinaDark)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.paperShade.opacity(0.45)))
        .accessibilityIdentifier(id)
    }
}
