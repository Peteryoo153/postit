import SwiftUI

/// 텍스트 앞의 컬러 라벨. 다크 라벨은 어두운 종이에서 3:1 이상이 되도록 한 단계 밝다.
enum NoteLabel: String, CaseIterable, Identifiable, Codable {
    case none, red, orange, yellow, green, blue, purple

    var id: String { rawValue }

    var color: Color { color(dark: false) }

    func color(dark: Bool) -> Color {
        switch self {
        case .none:   .clear
        case .red:    Theme.hex(dark ? 0xFF7B72 : 0xED544F)
        case .orange: Theme.hex(dark ? 0xFFA552 : 0xF89433)
        case .yellow: Theme.hex(dark ? 0xE9C53A : 0xD9B31A)
        case .green:  Theme.hex(dark ? 0x78CC80 : 0x5CB866)
        case .blue:   Theme.hex(dark ? 0x6AA6F2 : 0x458CE6)
        case .purple: Theme.hex(dark ? 0xB78BEE : 0x9E6BD9)
        }
    }

    /// "색상 없이 구별"이 켜졌을 때 막대 대신 쓰는 모양
    var shapeSymbol: String {
        switch self {
        case .none:   "circle.dashed"
        case .red:    "circle.fill"
        case .orange: "triangle.fill"
        case .yellow: "square.fill"
        case .green:  "diamond.fill"
        case .blue:   "star.fill"
        case .purple: "hexagon.fill"
        }
    }

    var title: String {
        switch self {
        case .none:   "라벨 없음"
        case .red:    "빨강"
        case .orange: "주황"
        case .yellow: "노랑"
        case .green:  "초록"
        case .blue:   "파랑"
        case .purple: "보라"
        }
    }
}
