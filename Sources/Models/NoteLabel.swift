import SwiftUI

/// 텍스트 앞의 컬러 라벨. 색상값은 Figma 디자인이 오면 Theme에서 교체.
enum NoteLabel: String, CaseIterable, Identifiable, Codable {
    case none, red, orange, yellow, green, blue, purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .none:   .clear
        case .red:    Theme.Label.red
        case .orange: Theme.Label.orange
        case .yellow: Theme.Label.yellow
        case .green:  Theme.Label.green
        case .blue:   Theme.Label.blue
        case .purple: Theme.Label.purple
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
