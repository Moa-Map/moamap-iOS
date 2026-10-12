import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// 카메라·갤러리 메뉴를 띄우고 고른 사진을 넘긴다. 읽지 못하면 data 가 nil 이다.
    /// 메뉴는 화면 가운데에 뜨고, `imageSourceMenuAnchor()` 를 단 칸이 있으면 그 칸의 아래 가운데에 붙는다.
    func imageSourcePicker(
        isPresented: Binding<Bool>, darkMenu: Bool = false, onPicked: @escaping (Data?, UTType?) -> Void
    ) -> some View {
        modifier(ImageSourcePickerModifier(showsMenu: isPresented, darkMenu: darkMenu, onPicked: onPicked))
    }

    func imageSourceMenuAnchor() -> some View {
        anchorPreference(key: ImageSourceMenuAnchorKey.self, value: .bounds) { $0 }
    }
}

private nonisolated struct ImageSourceMenuAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private struct ImageSourcePickerModifier: ViewModifier {
    @Binding var showsMenu: Bool
    let darkMenu: Bool
    let onPicked: (Data?, UTType?) -> Void

    @State private var showsGallery = false
    @State private var cameraRequested = false
    @State private var photoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(ImageSourceMenuAnchorKey.self) { anchor in
                if showsMenu { menu(anchor: anchor) }
            }
            .photosPicker(isPresented: $showsGallery, selection: $photoItem, matching: .images)
            .cameraCapture(isRequested: $cameraRequested) { data in onPicked(data, .jpeg) }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    onPicked(data, item.supportedContentTypes.first)
                }
            }
    }

    private func menu(anchor: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { showsMenu = false }
                    .accessibilityHidden(true)
                if let anchor {
                    let rect = proxy[anchor]
                    actionMenu
                        .frame(width: rect.width, height: rect.height, alignment: .bottom)
                        .offset(x: rect.minX, y: rect.minY)
                } else {
                    actionMenu.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var actionMenu: some View {
        ActionMenu(items: [
            ActionMenuItem(icon: "photo-camera", label: "카메라") {
                showsMenu = false
                cameraRequested = true
            },
            ActionMenuItem(icon: "gallery", label: "갤러리") {
                showsMenu = false
                showsGallery = true
            }
        ], dark: darkMenu)
        .accessibilityAction(.escape) { showsMenu = false }
    }

}
