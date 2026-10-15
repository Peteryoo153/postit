import SwiftUI

/// 고정 디자인 토큰 (Figma 스티키 기준). 사용자가 바꾸는 값은 StickySettings에 있다.
enum Theme {
    static let canvas = Color(red: 0.96, green: 0.96, blue: 0.96)       // 점 배경
    static let canvasDot = Color.black.opacity(0.12)
    static let ink = Color(red: 0.16, green: 0.15, blue: 0.13)
    static let author = Color.black.opacity(0.45)

    static let padding: CGFloat = 32
    #if os(macOS)
    /// 창 버튼을 숨겼으므로 좌우보다 조금 넉넉하게
    static let topPadding: CGFloat = 44
    #else
    static let topPadding: CGFloat = 40
    #endif
    static let bottomPadding: CGFloat = 32
    static let pageSize = 30

    enum Label {
        static let red = Color(red: 0.93, green: 0.33, blue: 0.31)
        static let orange = Color(red: 0.97, green: 0.58, blue: 0.20)
        static let yellow = Color(red: 0.85, green: 0.70, blue: 0.10)
        static let green = Color(red: 0.36, green: 0.72, blue: 0.40)
        static let blue = Color(red: 0.27, green: 0.55, blue: 0.90)
        static let purple = Color(red: 0.62, green: 0.42, blue: 0.85)
    }
}

/// 포스트잇 종이 색상 (사용자 선택).
enum PaperColor: String, CaseIterable, Identifiable {
    case yellow, orange, pink, violet, blue, green, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: Color(red: 0.976, green: 0.851, blue: 0.467)   // Figma 스티키 노랑
        case .orange: Color(red: 1.000, green: 0.776, blue: 0.537)
        case .pink:   Color(red: 1.000, green: 0.769, blue: 0.839)
        case .violet: Color(red: 0.851, green: 0.784, blue: 1.000)
        case .blue:   Color(red: 0.737, green: 0.871, blue: 1.000)
        case .green:  Color(red: 0.765, green: 0.929, blue: 0.753)
        case .gray:   Color(red: 0.902, green: 0.902, blue: 0.902)
        }
    }

    var title: String {
        switch self {
        case .yellow: "노랑"
        case .orange: "주황"
        case .pink:   "분홍"
        case .violet: "보라"
        case .blue:   "파랑"
        case .green:  "초록"
        case .gray:   "회색"
        }
    }
}

enum StickyFont: String, CaseIterable, Identifiable {
    case system, rounded, serif, mono, handwriting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:      "기본"
        case .rounded:     "둥근"
        case .serif:       "명조"
        case .mono:        "고정폭"
        case .handwriting: "손글씨"
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system:      .system(size: size, weight: weight)
        case .rounded:     .system(size: size, weight: weight, design: .rounded)
        case .serif:       .system(size: size, weight: weight, design: .serif)
        case .mono:        .system(size: size, weight: weight, design: .monospaced)
        case .handwriting: .custom("Noteworthy", size: size).weight(weight)
        }
    }
}

enum StickyWeight: String, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:    "가늘게"
        case .regular:  "보통"
        case .medium:   "중간"
        case .semibold: "약간 굵게"
        case .bold:     "굵게"
        }
    }

    var weight: Font.Weight {
        switch self {
        case .light:    .light
        case .regular:  .regular
        case .medium:   .medium
        case .semibold: .semibold
        case .bold:     .bold
        }
    }
}
