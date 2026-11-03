import SwiftUI

/// How to play: notices pinned to a cork board, one rule per page.
struct NoticeBoardView: View {
    @State private var viewModel: GuideViewModel

    init(viewModel: GuideViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $viewModel.pageIndex) {
                ForEach(viewModel.pages) { page in
                    ScrollView {
                        notice(page)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .frame(maxWidth: Theme.Metrics.maxContentWidth)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pins

            Button(action: { withAnimation(.spring(duration: 0.35)) { viewModel.advance() } }) {
                Text(viewModel.primaryTitle)
                    .frame(maxWidth: 320)
            }
            .buttonStyle(CopperButtonStyle(isProminent: viewModel.isLastPage))
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
            .accessibilityIdentifier(viewModel.isLastPage ? AccessibilityID.Guide.done : AccessibilityID.Guide.next)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Guide.screen)
    }

    private func notice(_ page: GuidePage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ArtImage(page.art)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.Colors.copperDark, lineWidth: 2))
            Text("Notice \(page.id + 1) of \(viewModel.pages.count)")
                .font(.body(12, relativeTo: .caption, bold: true))
                .tracking(1.4)
                .foregroundStyle(Theme.Colors.copperDark)
            Text(page.title)
                .font(.display(24, relativeTo: .title2))
                .foregroundStyle(Theme.Colors.ink)
                .accessibilityAddTraits(.isHeader)
            Text(page.body)
                .font(.body(17))
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.cream)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
        }
        .overlay(alignment: .top) {
            Circle()
                .fill(Theme.Colors.lava)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
                .frame(width: 16, height: 16)
                .offset(y: -6)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(page.id.isMultiple(of: 2) ? -0.8 : 0.8))
        .padding(.top, 8)
    }

    /// Push-pin page indicator.
    private var pins: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.pages) { page in
                Circle()
                    .fill(page.id == viewModel.pageIndex ? Theme.Colors.lava : Theme.Colors.paperShade)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.5), lineWidth: 1))
                    .frame(width: page.id == viewModel.pageIndex ? 13 : 9, height: page.id == viewModel.pageIndex ? 13 : 9)
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.pageIndex)
        .accessibilityElement()
        .accessibilityLabel("Notice \(viewModel.pageIndex + 1) of \(viewModel.pages.count)")
    }
}

private extension Theme.Colors {
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.89)
}
