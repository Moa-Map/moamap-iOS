import SwiftUI

/// 설정 「문의하기」. 유형·답변 받을 이메일·내용을 다 채우면 아래 버튼이 켜진다.
/// 접수되면 팝업을 띄우고, 닫으면 설정으로 돌아간다.
struct InquiryView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: InquiryViewModel
    @State private var typeMenuVisible = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, content }

    /// 아래 버튼(54 + 위아래 12).
    private static let submitAreaHeight: CGFloat = 54 + 12 * 2
    private static let contentFieldHeight: CGFloat = 200
    private static let typeMenuRowHeight: CGFloat = 50

    init(viewModel: InquiryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var state: InquiryUiState { viewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "문의하기") { dismiss() }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heading
                        typeField
                        emailField
                        contentField
                    }
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .keyboardOverlapPadding()
                .onChange(of: focusedField) { _, field in scroll(proxy, to: field) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    scroll(proxy, to: focusedField)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CreateMapSubmitButton(title: "문의하기", enabled: state.canSubmit, submitting: state.submitting) {
                focusedField = nil
                viewModel.submit()
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.vertical, 12)
        }
        // 버튼이 키보드를 따라 올라오지 않게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        // 유형 목록은 화면 맨 위에 띄워 아래 칸을 덮고, 밖을 누르면 닫는다. 밑의 칸·스크롤로는 넘기지 않는다.
        .overlayPreferenceValue(TypeFieldBoundsKey.self) { anchor in
            if typeMenuVisible, let anchor {
                GeometryReader { geometry in
                    let bounds = geometry[anchor]
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { typeMenuVisible = false }
                    typeMenu
                        .frame(width: bounds.width)
                        .offset(x: bounds.minX, y: bounds.maxY)
                }
            }
        }
        .moaSnackbar($errorMessage, bottomInset: Self.submitAreaHeight)
        .overlay {
            if state.submitted {
                MoaMapAlertDialog(title: "문의가 접수됐어요") { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { viewModel.prefillEmail() }
        .onChange(of: state.errorMessage, initial: true) { _, message in
            guard let message else { return }
            errorMessage = message
            viewModel.consumeError()
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to field: Field?) {
        guard field == .content else { return }
        withAnimation { proxy.scrollTo(Field.content, anchor: .bottom) }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("무엇을 도와드릴까요?")
                .moaTextStyle(typography.subtitle1)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            Text("궁금한 점이나 불편한 점을 알려주세요")
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
        }
        .padding(.leading, 4)
    }

    private var typeField: some View {
        field("문의 유형", highlighted: typeMenuVisible) {
            Button {
                // 입력하던 키보드를 내려야 목록이 가리지 않는다.
                focusedField = nil
                typeMenuVisible.toggle()
            } label: {
                HStack(spacing: 10) {
                    Text(state.type?.label ?? "문의 유형을 선택해주세요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(state.type == nil ? colors.textAssistive : colors.textNormal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image("Icons/arrow-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(colors.textAssistive)
                        .rotationEffect(.degrees(typeMenuVisible ? -90 : 90))
                        .accessibilityHidden(true)
                }
                .frame(height: 21)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("문의 유형")
            .accessibilityValue(state.type?.label ?? "선택 안 함")
        }
        // 제목과 칸의 폭이 같고 아래 끝도 칸 끝이라 묶음 전체를 잰다.
        .anchorPreference(key: TypeFieldBoundsKey.self, value: .bounds) { $0 }
    }

    private var emailField: some View {
        field("답변 받을 이메일", highlighted: focusedField == .email) {
            HStack(spacing: 4) {
                TextField(
                    "",
                    text: Binding(get: { state.email }, set: { viewModel.updateEmail($0) }),
                    prompt: placeholder("답변 받을 이메일을 입력해주세요")
                )
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .tint(colors.primary)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .content }
                .accessibilityLabel("답변 받을 이메일")
                ClearTextButton(text: Binding(get: { state.email }, set: { viewModel.updateEmail($0) }))
            }
            .frame(height: 21)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var contentField: some View {
        field("문의 내용", highlighted: focusedField == .content) {
            // 높이는 고정이고 넘치는 글은 칸 안에서 스크롤한다.
            TextEditor(text: Binding(get: { state.content }, set: { viewModel.updateContent($0) }))
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .tint(colors.primary)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .content)
                // 글이 시스템 안쪽 여백만큼 밀리지 않게 자리 문구와 맞춘다.
                .padding(.horizontal, -5)
                .padding(.vertical, -8)
                .background(alignment: .topLeading) {
                    if state.content.isEmpty {
                        placeholder("궁금한 점이나 불편한 점을 자세히 적어주세요")
                            .moaTextStyle(typography.body2)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("문의 내용")
                // 아래는 글자 수 한 줄만큼 더 비워 글이 그 밑으로 들어가지 않게 한다.
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 40, trailing: 16))
                .frame(height: Self.contentFieldHeight)
                .overlay(alignment: .bottomTrailing) {
                    Text("\(state.content.count)/\(InquiryForm.contentMaxLength)")
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textAssistive)
                        .padding(16)
                        .accessibilityHidden(true)
                }
        }
        .id(Field.content)
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundStyle(colors.textAssistive)
    }

    /// 제목 + 흰 칸. 입력 중이거나 `highlighted` 면 테두리를 두른다.
    private func field(_ label: String, highlighted: Bool, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
                .padding(.leading, 2)
                .accessibilityHidden(true)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay { if highlighted { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.primary, lineWidth: 1) } }
                .shadow(color: .black.opacity(0.08), radius: 5)
        }
    }

    /// 바탕 #4A4F52 60% + 흐림, 모서리 12, 좌우 안쪽 4, 줄 높이 50, 흰 글자, 줄 사이 1px 선.
    private var typeMenu: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        return VStack(spacing: 0) {
            ForEach(Array(InquiryType.allCases.enumerated()), id: \.element) { index, type in
                Button {
                    viewModel.selectType(type)
                    typeMenuVisible = false
                } label: {
                    Text(type.label)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textWhite)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: Self.typeMenuRowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(type == state.type ? .isSelected : [])
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(colors.lineNormal).frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, 4)
        .background {
            shape.fill(.ultraThinMaterial)
            shape.fill(MoaMapPrimitiveColors.gray500.opacity(0.6))
        }
        .clipShape(shape)
    }
}

private struct TypeFieldBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

#if DEBUG
@MainActor
final class PreviewInquiryRepository: InquiryRepository {
    func sendInquiry(type: InquiryType, replyEmail: String, content: String) async throws {}
}

#Preview {
    NavigationStack {
        InquiryView(viewModel: InquiryViewModel(repository: PreviewInquiryRepository(), userRepository: PreviewUserRepository()))
    }
}
#endif
