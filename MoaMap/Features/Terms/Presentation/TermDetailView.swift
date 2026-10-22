import MarkdownUI
import SwiftUI

/// 약관 전문. 본문은 Markdown 으로 그리고 링크는 브라우저·메일 앱으로 연다.
struct TermDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TermDetailViewModel

    /// 불러오기 전에 상단 바에 보일 제목.
    let title: String

    init(viewModel: TermDetailViewModel, title: String) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: displayedTitle) { dismiss() }
            switch viewModel.uiState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                MoaMapRetryPrompt(message: message) { viewModel.load() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let detail):
                ScrollView {
                    Markdown(detail.content)
                        .markdownTheme(.basic)
                        .markdownTextStyle {
                            FontFamily(.custom(MoaMapFontName.nanumSquareRegular))
                            FontSize(typography.body2.size)
                            ForegroundColor(colors.textNormal)
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 34)
                }
            }
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.loadTask == nil { viewModel.load() }
        }
    }

    private var displayedTitle: String {
        if case .loaded(let detail) = viewModel.uiState, !detail.term.title.isEmpty { return detail.term.title }
        return title
    }
}
