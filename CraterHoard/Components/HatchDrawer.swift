import SwiftUI

/// The vault's own navigation surface: a paper-lined mine hatch that rises from the bottom
/// on iPhone and slides in from the right on iPad. Closed with the red valve wheel.
struct HatchDrawer<Content: View>: View {
    let panel: VaultPanel
    let onClose: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var dragOffset: CGFloat = 0

    private var isSide: Bool { sizeClass == .regular }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: isSide ? .trailing : .bottom) {
                Color.black.opacity(0.55)
                    .onTapGesture(perform: onClose)
                    .accessibilityLabel("Close \(panel.title)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier(AccessibilityID.Drawer.backdrop)

                hatch
                    .frame(
                        width: isSide ? min(500, proxy.size.width * 0.58) : proxy.size.width,
                        height: isSide ? proxy.size.height : max(320, proxy.size.height * 0.88)
                    )
                    .offset(x: isSide ? max(0, dragOffset) : 0, y: isSide ? 0 : max(0, dragOffset))
                    .transition(.move(edge: isSide ? .trailing : .bottom))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: isSide ? .trailing : .bottom)
        }
        // Measured in full-screen coordinates; the header and scroll content pad themselves.
        .ignoresSafeArea()
    }

    private var hatch: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: isSide ? 26 : 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: isSide ? 0 : 26,
                style: .continuous
            )
            .fill(ImagePaint(image: Image("tex_paper"), scale: 1))
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 26,
                    bottomLeadingRadius: isSide ? 26 : 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: isSide ? 0 : 26,
                    style: .continuous
                )
                .strokeBorder(
                    LinearGradient(colors: [Theme.Colors.copperLight, Theme.Colors.copperDark], startPoint: .top, endPoint: .bottom),
                    lineWidth: 5
                )
            }
            .shadow(color: .black.opacity(0.5), radius: 16, y: -4)
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 26,
            bottomLeadingRadius: isSide ? 26 : 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: isSide ? 0 : 26,
            style: .continuous
        ))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drawer.\(panel.rawValue)")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(panel.title)
                    .font(.display(22, relativeTo: .title2))
                    .foregroundStyle(Theme.Colors.goldLight)
                    .accessibilityAddTraits(.isHeader)
                Text(panel.subtitle.uppercased())
                    .font(.body(12, relativeTo: .caption, bold: true))
                    .tracking(1.6)
                    .foregroundStyle(Theme.Colors.paper.opacity(0.85))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background { PlaqueBackground() }

            Spacer(minLength: 8)

            Button(action: onClose) {
                ArtImage("valve_close")
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(dragOffset * 0.6))
            }
            .buttonStyle(PressableStyle())
            .frame(minWidth: 48, minHeight: 48)
            .accessibilityLabel("Close")
            .accessibilityIdentifier(AccessibilityID.Drawer.close)
        }
        .padding(.horizontal, 16)
        .padding(.top, isSide ? 60 : 18)
        .padding(.bottom, 10)
        .contentShape(Rectangle())
        // Only the header drags, so scrolling inside the panel keeps working.
        .gesture(dismissDrag)
        .overlay(alignment: .top) {
            if !isSide {
                Capsule()
                    .fill(Theme.Colors.copperDark.opacity(0.5))
                    .frame(width: 44, height: 5)
                    .padding(.top, 7)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Pull the hatch down (or to the right on iPad) to close it.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragOffset = isSide ? value.translation.width : value.translation.height
            }
            .onEnded { value in
                let travel = isSide ? value.translation.width : value.translation.height
                if travel > 140 {
                    onClose()
                }
                withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
            }
    }
}
