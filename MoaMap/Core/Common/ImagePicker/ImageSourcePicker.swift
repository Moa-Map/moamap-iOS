import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// 카메라·갤러리 메뉴를 화면 가운데에 띄우고 고른 사진을 넘긴다. 읽지 못하면 data 가 nil 이다.
    func imageSourcePicker(isPresented: Binding<Bool>, onPicked: @escaping (Data?, UTType?) -> Void) -> some View {
        modifier(ImageSourcePickerModifier(showsMenu: isPresented, onPicked: onPicked))
    }
}

private struct ImageSourcePickerModifier: ViewModifier {
    @Binding var showsMenu: Bool
    let onPicked: (Data?, UTType?) -> Void

    @State private var showsGallery = false
    @State private var cameraRequested = false
    @State private var photoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .overlay { if showsMenu { menu } }
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

    private var menu: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showsMenu = false }
                .accessibilityHidden(true)
            actionMenu
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
        ])
        .accessibilityAction(.escape) { showsMenu = false }
    }

}
