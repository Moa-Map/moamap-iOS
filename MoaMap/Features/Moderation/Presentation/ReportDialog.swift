import SwiftUI

nonisolated extension ReportReason {
    var label: String {
        switch self {
        case .spam: "스팸·광고·도배"
        case .abuse: "욕설·비하·혐오 표현"
        case .sexual: "음란·선정적 내용·부적절한 사진"
        case .privacy: "개인정보 노출"
        case .falseInfo: "사실과 다른 정보"
        case .other: "기타"
        }
    }
}

/// 사유를 골라 신고하는 팝업. 모양은 `MoaMapConfirmDialog` 와 같다. 신고를 눌러도 스스로 닫지 않는다.
struct ReportDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    /// 서버가 받는 길이.
    static let detailMaxLength = 200

    let title: String
    var isSubmitting = false
    let onSubmit: (ReportReason, String?) -> Void
    let onDismiss: () -> Void

    @State private var reason = ReportReason.allCases[0]
    @State private var detail = ""
    @FocusState private var detailFocused: Bool

    private var canSubmit: Bool {
        !isSubmitting && (reason != .other || !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        ZStack {
            MoaMapPrimitiveColors.dialogScrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                Text(title)
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        radio(reason)
                    }
                    if reason == .other { detailField }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    button("취소", color: MoaMapPrimitiveColors.gray200, action: onDismiss)
                    button("신고하기", color: MoaMapPrimitiveColors.blue500) {
                        onSubmit(reason, reason == .other ? detail : nil)
                    }
                    .disabled(!canSubmit)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 20)
            .frame(width: 300)
            .background(colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
        }
        .onChange(of: reason) { _, reason in detailFocused = reason == .other }
    }

    private func radio(_ option: ReportReason) -> some View {
        let selected = option == reason
        return Button { reason = option } label: {
            HStack(spacing: 16) {
                Circle()
                    .strokeBorder(selected ? MoaMapPrimitiveColors.blue500 : MoaMapPrimitiveColors.gray100, lineWidth: 1)
                    .overlay {
                        if selected { Circle().fill(MoaMapPrimitiveColors.blue500).padding(3) }
                    }
                    .frame(width: 20, height: 20)
                Text(option.label)
                    .moaTextStyle(typography.body1)
                    .foregroundStyle(colors.textNormal)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var detailField: some View {
        // 높이는 고정이고 넘치는 글은 칸 안에서 스크롤한다.
        TextEditor(text: Binding(get: { detail }, set: { detail = String($0.prefix(Self.detailMaxLength)) }))
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(colors.primary)
            .scrollContentBackground(.hidden)
            .focused($detailFocused)
            // 글이 시스템 안쪽 여백만큼 밀리지 않게 자리 문구와 맞춘다.
            .padding(.horizontal, -5)
            .padding(.vertical, -8)
            .background(alignment: .topLeading) {
                if detail.isEmpty {
                    Text("신고 사유를 입력해주세요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel("신고 사유")
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(height: 90)
            .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
    }

    private func button(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.04), radius: 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReportDialog(title: "댓글 신고하기", onSubmit: { _, _ in }, onDismiss: {})
}
