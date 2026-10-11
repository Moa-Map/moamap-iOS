import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// 고른 사진 한 장. 읽지 못하면 data 가 nil 이다.
struct PickedPhoto {
    let data: Data?
    let type: UTType?
}

/// 앨범 사진을 격자로 보여 주고 여러 장을 고른다. 맨 앞 칸은 카메라다.
/// 고른 순서대로 넘기고, 카메라로 찍으면 그때까지 고른 사진 뒤에 붙여 바로 넘긴다.
struct PhotoLibraryPicker: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// 더 붙일 수 있는 장수.
    let maxSelection: Int
    let onCancel: () -> Void
    let onPicked: ([PickedPhoto]) -> Void

    @State private var library = PhotoLibrary()
    /// 고른 사진의 `localIdentifier`. 보관함이 바뀌면 같은 사진도 새 객체로 오기 때문에 식별자로 들고 있는다.
    @State private var selection: [String] = []
    @State private var loading = false
    /// 원본을 받는 작업. 받는 도중에 나가면 멈춰서, 늦게 끝난 결과가 폼에 붙지 않게 한다.
    @State private var finishTask: Task<Void, Never>?
    @State private var showsCamera = false
    /// 찍은 사진. 카메라가 다 닫힌 뒤에 넘긴다. 닫히는 중에 이 화면까지 닫으면 UIKit 이 무시한다.
    @State private var captured: PickedPhoto?
    @State private var cameraAlert: CameraAlert?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoaMapTopBar(title: "사진 선택", onBack: cancel) {
                Button { finish() } label: {
                    MoaMapTopBarIcon(name: "arrow-forward")
                        .opacity(selection.isEmpty ? 0.3 : 1)
                }
                .buttonStyle(.plain)
                .disabled(selection.isEmpty || loading)
                .accessibilityLabel("다음")
            }
            albumMenu
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 12)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    cameraCell
                    ForEach(0..<library.assets.count, id: \.self) { index in
                        let asset = library.assets[index]
                        Button { toggle(asset.localIdentifier) } label: {
                            PhotoLibraryCell(asset: asset, library: library, order: order(of: asset.localIdentifier))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                if library.access == .denied { deniedNotice }
                if library.access == .limited { limitedNotice }
            }
            .scrollIndicators(.hidden)
        }
        .background(colors.backgroundSecondary)
        .overlay { if loading { ProgressView() } }
        .task { await library.load() }
        // 설정에서 사진 접근을 바꾸고 돌아오면 다시 확인한다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await library.load() } }
        }
        .onDisappear {
            finishTask?.cancel()
            library.stop()
        }
        .fullScreenCover(isPresented: $showsCamera, onDismiss: {
            guard let photo = captured else { return }
            captured = nil
            finish(adding: photo)
        }) {
            CameraPicker { data in captured = PickedPhoto(data: data, type: .jpeg) }
                .ignoresSafeArea()
        }
        .alert(cameraAlert?.title ?? "", isPresented: showsCameraAlert, presenting: cameraAlert) { alert in
            if alert == .denied {
                Button("설정 열기", action: openSettings)
                Button("취소", role: .cancel) {}
            } else {
                Button("확인", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
    }

    /// 앨범이 하나뿐이면 고를 것이 없어 이름만 보인다.
    private var albumMenu: some View {
        Menu {
            ForEach(library.albums, id: \.localIdentifier) { album in
                Button(album.localizedTitle ?? "") { library.select(album) }
            }
        } label: {
            HStack(spacing: 0) {
                Text(library.album?.localizedTitle ?? "최근 항목")
                    .moaTextStyle(typography.subtitle4)
                Image("Icons/arrow-right")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
            }
            .foregroundStyle(colors.textNormal)
        }
        .disabled(library.albums.count < 2)
    }

    private var cameraCell: some View {
        Button(action: openCamera) {
            Color(argb: 0xFF37_3737)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image("Icons/camera-solid")
                        .resizable()
                        .frame(width: 32, height: 32)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("카메라")
    }

    private var deniedNotice: some View {
        VStack(spacing: 12) {
            Text("설정에서 사진 접근을 허용하면 앨범의 사진을 고를 수 있어요.")
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
                .multilineTextAlignment(.center)
            Button("설정 열기", action: openSettings)
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textNormal)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .padding(.top, 40)
    }

    /// 일부만 허용했으면 허용할 사진을 더 고를 수 있게 한다. 고르고 나면 보관함 변경 알림으로 격자가 갱신된다.
    private var limitedNotice: some View {
        VStack(spacing: 12) {
            Text("허용한 사진만 보여요.")
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
            Button("사진 더 허용하기", action: PhotoLibrary.presentLimitedPicker)
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textNormal)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .padding(.vertical, 24)
    }

    /// 1부터 센 고른 순서. 고르지 않았으면 nil.
    private func order(of id: String) -> Int? {
        selection.firstIndex(of: id).map { $0 + 1 }
    }

    /// 다 찼으면 더 고르지 않는다. 고른 것을 빼는 것은 언제든 된다.
    private func toggle(_ id: String) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else if selection.count < maxSelection {
            selection.append(id)
        }
    }

    private func finish(adding captured: PickedPhoto? = nil) {
        guard !loading else { return }
        loading = true
        let ids = selection
        finishTask = Task {
            var photos: [PickedPhoto] = []
            for id in ids { photos.append(await library.photo(for: id)) }
            if let captured { photos.append(captured) }
            loading = false
            guard !Task.isCancelled else { return }
            onPicked(photos)
        }
    }

    private func cancel() {
        finishTask?.cancel()
        onCancel()
    }

    /// 이미 다 골랐으면 찍어도 붙일 자리가 없다.
    private func openCamera() {
        guard selection.count < maxSelection else { return }
        guard CameraPicker.isAvailable else {
            cameraAlert = .unavailable
            return
        }
        Task {
            if await CameraPicker.requestAccess() { showsCamera = true } else { cameraAlert = .denied }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var showsCameraAlert: Binding<Bool> {
        Binding(get: { cameraAlert != nil }, set: { if !$0 { cameraAlert = nil } })
    }
}

private struct PhotoLibraryCell: View {
    @Environment(\.moaTypography) private var typography
    @Environment(\.displayScale) private var displayScale

    let asset: PHAsset
    let library: PhotoLibrary
    let order: Int?

    @State private var image: UIImage?

    var body: some View {
        MoaMapPrimitiveColors.gray50
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay { Rectangle().strokeBorder(MoaMapPrimitiveColors.white, lineWidth: 1) }
            .overlay(alignment: .topTrailing) { indicator.padding(.top, 5).padding(.trailing, 4.67) }
            .contentShape(Rectangle())
            // 칸은 화면 폭의 4분의 1 남짓이다. 배율을 곱해야 흐려지지 않는다.
            .task(id: asset.localIdentifier) { image = await library.thumbnail(for: asset, side: 100 * displayScale) }
            .accessibilityElement()
            .accessibilityLabel(order.map { "사진, \($0)번째로 고름" } ?? "사진")
            .accessibilityAddTraits(order == nil ? .isButton : [.isButton, .isSelected])
    }

    private var indicator: some View {
        ZStack {
            Circle().fill(order == nil ? Color(argb: 0x99D9_D9D9) : MoaMapPrimitiveColors.blue500)
            Circle().strokeBorder(MoaMapPrimitiveColors.white, lineWidth: 1)
            if let order {
                Text("\(order)")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(MoaMapPrimitiveColors.white)
            }
        }
        .frame(width: 20, height: 20)
        .shadow(color: .black.opacity(0.07), radius: 8, y: 4)
    }
}

/// 사진 보관함 접근, 앨범, 앨범 속 사진을 들고 있는다.
@MainActor @Observable
private final class PhotoLibrary: NSObject, PHPhotoLibraryChangeObserver {
    enum Access { case unknown, granted, limited, denied }

    private(set) var access = Access.unknown
    private(set) var albums: [PHAssetCollection] = []
    private(set) var album: PHAssetCollection?
    /// 배열로 옮기지 않는다. 사진이 수만 장이어도 보이는 칸만 꺼내 쓴다.
    private(set) var assets = PHFetchResult<PHAsset>()

    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private var registered = false

    /// 일부만 허용해도 그 사진들은 보여 준다.
    func load() async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard status == .authorized || status == .limited else {
            access = .denied
            return
        }
        access = status == .limited ? .limited : .granted
        if !registered {
            registered = true
            PHPhotoLibrary.shared().register(self)
        }
        reload()
    }

    /// 화면이 닫히면 보관함 변경 알림을 그만 받는다. 다시 열면 `load()` 가 다시 등록한다.
    func stop() {
        guard registered else { return }
        registered = false
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    /// 시스템의 허용 사진 고르기 창은 UIKit 화면 위에만 띄울 수 있어 맨 위 화면을 찾아 띄운다.
    static func presentLimitedPicker() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        guard let top else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    func select(_ album: PHAssetCollection) {
        self.album = album
        assets = Self.images(in: album)
    }

    /// 격자 칸 크기에 맞춘 미리보기.
    func thumbnail(for asset: PHAsset, side: CGFloat) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill, options: options
            ) { image, _ in continuation.resume(returning: image) }
        }
    }

    /// 올릴 원본. iCloud 에만 있는 사진은 내려받는다. 그새 지워졌으면 읽지 못한 사진으로 넘긴다.
    func photo(for id: String) async -> PickedPhoto {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return PickedPhoto(data: nil, type: nil)
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, _ in
                continuation.resume(returning: PickedPhoto(data: data, type: uti.flatMap(UTType.init)))
            }
        }
    }

    /// 허용한 사진을 바꾸거나 새로 찍으면 다시 읽는다.
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in self.reload() }
    }

    /// 최근 항목을 맨 앞에 두고, 사진이 없는 앨범은 뺀다. 보던 앨범이 남아 있으면 그대로 둔다.
    private func reload() {
        var next: [PHAssetCollection] = []
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil)
            .enumerateObjects { collection, _, _ in next.append(collection) }
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
            .enumerateObjects { collection, _, _ in next.append(collection) }
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            .enumerateObjects { collection, _, _ in next.append(collection) }
        albums = next.filter { Self.images(in: $0, limit: 1).count > 0 }
        let current = albums.first { $0.localIdentifier == album?.localIdentifier } ?? albums.first
        if let current { select(current) } else { album = nil; assets = PHFetchResult() }
    }

    private static func images(in album: PHAssetCollection, limit: Int = 0) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit
        return PHAsset.fetchAssets(in: album, options: options)
    }
}
