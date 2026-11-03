import SwiftUI

/// Shows a transient paper slip near the bottom of the screen.
struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(spacing: 10) {
                        Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(isError ? Theme.Colors.danger : Theme.Colors.patinaDark)
                            .accessibilityHidden(true)
                        Text(message)
                            .font(.body(16, bold: true))
                            .foregroundStyle(Theme.Colors.ink)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background { PaperBackground(cornerRadius: 12) }
                    .padding(.bottom, 18)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(AccessibilityID.toast)
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.25)) { self.message = nil }
                    }
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.2), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, isError: Bool = false) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}
