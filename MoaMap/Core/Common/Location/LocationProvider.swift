import CoreLocation

nonisolated enum LocationAuthorization: Sendable {
    case notDetermined
    case granted
    case denied
}

@MainActor
protocol LocationProvider: AnyObject {
    var authorization: LocationAuthorization { get }
    /// 아직 묻지 않았으면 묻고 답을 돌려준다. 이미 답했으면 바로 돌려준다.
    func requestAuthorization() async -> LocationAuthorization
    /// 하드웨어를 깨우지 않고 캐시된 좌표만 읽는다.
    var lastKnownLocation: CLLocationCoordinate2D? { get }
    /// 지금 위치. 못 얻으면 nil.
    func currentLocation() async -> CLLocationCoordinate2D?
}

@MainActor
final class DeviceLocationProvider: NSObject, LocationProvider {
    /// 실내나 약신호에서는 첫 좌표가 오지 않을 수 있다. 버튼이 잠긴 채로 남지 않게 끊는다.
    static let timeout: Duration = .seconds(5)

    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<LocationAuthorization, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorization: LocationAuthorization {
        switch manager.authorizationStatus {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .granted
        default: .denied
        }
    }

    func requestAuthorization() async -> LocationAuthorization {
        guard authorization == .notDetermined else { return authorization }
        return await withCheckedContinuation { continuation in
            authorizationWaiters.append(continuation)
            if authorizationWaiters.count == 1 { manager.requestWhenInUseAuthorization() }
        }
    }

    var lastKnownLocation: CLLocationCoordinate2D? {
        authorization == .granted ? manager.location?.coordinate : nil
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        guard authorization == .granted else { return nil }
        if let cached = manager.location, -cached.timestamp.timeIntervalSinceNow < 60 {
            return cached.coordinate
        }
        let timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.timeout)
            guard !Task.isCancelled else { return }
            self?.finishLocation(nil)
        }
        defer { timeout.cancel() }
        return await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            if locationWaiters.count == 1 { manager.requestLocation() }
        }
    }

    private func finishLocation(_ coordinate: CLLocationCoordinate2D?) {
        let waiters = locationWaiters
        locationWaiters.removeAll()
        waiters.forEach { $0.resume(returning: coordinate) }
    }
}

extension DeviceLocationProvider: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard authorization != .notDetermined else { return }
        let waiters = authorizationWaiters
        authorizationWaiters.removeAll()
        waiters.forEach { $0.resume(returning: authorization) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 묶음은 오래된 것부터라 마지막이 가장 새 좌표다.
        finishLocation(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        finishLocation(nil)
    }
}
