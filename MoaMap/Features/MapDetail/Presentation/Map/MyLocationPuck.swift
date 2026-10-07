import MapboxMaps

extension Puck2D {
    /// 지도 위 내 위치. 다른 지도 앱처럼 파란 점에 휴대폰이 향한 방향을 함께 그리고, 내가 움직이면 따라
    /// 움직인다(지도 라이브러리 기본 그림). 지도를 그리는 모든 화면이 `Map` 안에서 쓴다.
    ///
    /// 위치 권한이 있을 때만 넣는다. 넣는 순간 지도 라이브러리가 위치를 받기 시작하고, 권한이 없으면 스스로 묻는다.
    static var myLocation: Puck2D { Puck2D(bearing: .heading) }
}
