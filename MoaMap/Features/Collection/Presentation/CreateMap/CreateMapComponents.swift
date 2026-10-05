import SwiftUI
import UIKit

/// 칸 제목. 필수 칸이면 뒤에 빨간 별표를 붙이고 "필수"로 읽힌다.
struct CreateMapLabel: View {
    @Environment(\.moaColors) private var colors

    let text: String
    let style: MoaMapTextStyle
    var required = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text).foregroundStyle(colors.textNormal)
            if required { Text("*").foregroundStyle(colors.statusAlert) }
        }
        .moaTextStyle(style)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(required ? "\(text), 필수" : text)
        .accessibilityAddTraits(.isHeader)
    }
}

/// 지도 사진 카드. 고른 사진이 있으면 카드를 채워 보여준다.
struct MapPhotoField: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let image: UIImage?
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CreateMapLabel(text: "지도 사진", style: typography.subtitle1)
            Button(action: onTap) {
                Color.white
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .overlay {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            VStack(spacing: 2) {
                                Image("Icons/add").renderingMode(.template).resizable()
                                    .frame(width: 32, height: 32)
                                Text("사진 추가하기").moaTextStyle(typography.body2)
                            }
                            .foregroundStyle(colors.textAssistive)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.04), radius: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(image == nil ? "지도 사진 추가하기" : "지도 사진 바꾸기")
            .imageSourceMenuAnchor()
        }
    }
}

/// 라벨과 한 줄 입력창. 태그처럼 사이에 끼는 내용은 `accessory` 로 넣는다.
struct CreateMapInputField<Accessory: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let label: String
    var required = false
    @Binding var text: String
    let placeholder: String
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CreateMapLabel(text: label, style: typography.subtitle2, required: required)
                .padding(.leading, 2)
            accessory()
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(colors.textAssistive))
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .tint(colors.primary)
                .accessibilityLabel(label)
                // 입력값과 안내 문구의 줄 높이가 달라 칸 높이가 바뀌지 않게 고정한다.
                .frame(height: 21)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4)
        }
    }
}

extension CreateMapInputField where Accessory == EmptyView {
    init(label: String, required: Bool = false, text: Binding<String>, placeholder: String) {
        self.init(label: label, required: required, text: text, placeholder: placeholder) { EmptyView() }
    }
}

/// 공개 범위 카드. 고르면 파란 배경·테두리로 바뀌고 제목이 굵어진다.
struct VisibilityCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let iconName: String
    let title: String
    let subtitle: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16)
        let contentColor = selected ? MoaMapPrimitiveColors.blue700 : colors.textAssistive
        Button(action: onTap) {
            VStack(spacing: 11) {
                Image("Icons/\(iconName)").renderingMode(.template).resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(selected ? MoaMapPrimitiveColors.blue700 : colors.textAlternative)
                    .accessibilityHidden(true)
                Text(title).moaTextStyle(selected ? typography.body3 : typography.body2)
                Text(subtitle).moaTextStyle(typography.caption0)
            }
            .foregroundStyle(contentColor)
            .frame(maxWidth: .infinity).frame(height: 113)
            .background(selected ? MoaMapPrimitiveColors.blue50 : MoaMapPrimitiveColors.white, in: shape)
            .overlay { if selected { shape.strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) } }
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 담은 태그. 누르면 지운다.
struct TagChip: View {
    @Environment(\.moaTypography) private var typography

    let tag: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 2) {
                Text(tag).moaTextStyle(typography.caption0)
                Image("Icons/close").renderingMode(.template).resizable()
                    .frame(width: 14, height: 14)
            }
            .foregroundStyle(MoaMapPrimitiveColors.yellow900)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
            .overlay { Capsule().strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag) 태그 삭제")
    }
}

/// URL 로 장소 추가 허용 설정. 행 전체를 눌러도 바뀐다.
struct URLImportToggleRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL로 장소 추가 허용하기")
                        .moaTextStyle(typography.subtitle1)
                        .foregroundStyle(colors.textNormal)
                    Text("URL을 붙여넣어 장소를 추가할 수 있어요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Circle()
                    .fill(MoaMapPrimitiveColors.white)
                    .frame(width: 18, height: 18)
                    .padding(3)
                    .frame(width: 48, height: 24, alignment: isOn ? .trailing : .leading)
                    .background(isOn ? colors.primary : Color(argb: 0xFFB1B3B4), in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("URL로 장소 추가 허용하기")
        .accessibilityValue(isOn ? "켬" : "끔")
        .accessibilityAddTraits(.isToggle)
    }
}

struct CreateMapSubmitButton: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let enabled: Bool
    let submitting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if submitting {
                    ProgressView().tint(colors.textWhite)
                } else {
                    Text("지도 만들기")
                        .moaTextStyle(typography.button0)
                        .foregroundStyle(colors.textWhite)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(enabled ? colors.primary : MoaMapPrimitiveColors.gray200, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(SolidButtonStyle())
        .disabled(!enabled)
    }
}

/// 비활성일 때 흐려지지 않게 한다. 회색 배경으로 이미 구분된다.
private struct SolidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
