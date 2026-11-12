import SwiftUI

/// 고정 디자인 토큰 (Postit Design v1). 사용자가 바꾸는 값은 StickySettings에 있다.
/// 색은 종이 색과 라이트/다크에 따라 달라지므로 `Palette`로 묶어 환경값으로 내려보낸다.
enum Theme {
    static let padding: CGFloat = 32
    #if os(macOS)
    /// 위쪽 42pt = 끌기 · 더블클릭(접기) · 우클릭(포스트잇 메뉴) 영역
    static let topPadding: CGFloat = 42
    #else
    static let topPadding: CGFloat = 12
    #endif
    static let bottomPadding: CGFloat = 28
    static let pageSize = 30

    /// 종이 그림자 색: 검정 대신 따뜻한 갈색
    static let shadowBrown = Color(red: 60 / 255, green: 45 / 255, blue: 10 / 255)

    static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255,
              green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }
}

/// 지금 종이에 쓰는 색 묶음 (종이 색 × 라이트/다크).
struct Palette {
    var paperColor: PaperColor = .yellow
    var isDark = false

    var paper: Color { paperColor.color(dark: isDark) }
    var ink: Color { isDark ? Theme.hex(0xEFE8D8) : Theme.hex(0x29261F) }
    /// 보조 글자: 라이트 검정 58% · 다크 미색 64%
    var secondary: Color { isDark ? Theme.hex(0xEFE8D8).opacity(0.64) : Color.black.opacity(0.58) }
    var hairline: Color { ink.opacity(isDark ? 0.18 : 0.14) }
    var overdue: Color { isDark ? Theme.hex(0xFF8A80) : Theme.hex(0xC4302B) }
    var caret: Color { isDark ? Theme.hex(0xF2C94C) : Theme.hex(0x2F6FDB) }
    /// 체크박스 채움 = 잉크 78%, 체크 = 종이색
    var checkFill: Color { ink.opacity(0.78) }

    func label(_ label: NoteLabel) -> Color { label.color(dark: isDark) }
}

extension EnvironmentValues {
    @Entry var palette = Palette()
}

/// 포스트잇 종이 색상 (사용자 선택). 다크는 같은 색상(hue)에 명도를 크게 낮춘 "어두운 크라프트지" 톤.
enum PaperColor: String, CaseIterable, Identifiable {
    case yellow, orange, pink, violet, blue, green, gray

    var id: String { rawValue }

    var color: Color { color(dark: false) }

    func color(dark: Bool) -> Color {
        switch self {
        case .yellow: Theme.hex(dark ? 0x463D29 : 0xF9D977)
        case .orange: Theme.hex(dark ? 0x4A3829 : 0xFFC689)
        case .pink:   Theme.hex(dark ? 0x4A3139 : 0xFFC4D6)
        case .violet: Theme.hex(dark ? 0x3A3350 : 0xD9C8FF)
        case .blue:   Theme.hex(dark ? 0x2B3C4E : 0xBCDEFF)
        case .green:  Theme.hex(dark ? 0x2E4231 : 0xC3EDC0)
        case .gray:   Theme.hex(dark ? 0x3B3B3A : 0xE6E6E6)
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

/// 화면 모드: 시스템을 따르거나 라이트/다크로 고정
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "시스템"
        case .light:  "라이트"
        case .dark:   "다크"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
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

// MARK: - 종이 표면: 색 · 질감 · 위아래 빛

/// 종이 한 장의 바탕. 노이즈+섬유 질감(라이트 multiply 13% · 다크 screen 20%),
/// 위 40pt 흰빛(접착 띠), 아래 28pt 갈색(살짝 들린 아래 끝).
struct PaperSurface: View {
    @Environment(\.palette) private var palette
    var texture = true

    var body: some View {
        ZStack {
            palette.paper
            if texture {
                // 흰 바탕에 결만 알파로 담은 타일을 갈색(라이트)/흰색(다크)으로 칠해 얹는다
                Image("PaperTexture")
                    .renderingMode(.template)
                    .resizable(resizingMode: .tile)
                    .foregroundStyle(palette.isDark ? Color.white : Theme.shadowBrown)
                    .opacity(palette.isDark ? 0.12 : 0.13)
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    LinearGradient(colors: [.white.opacity(palette.isDark ? 0.06 : 0.22), .white.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 40)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [Theme.shadowBrown.opacity(0), Theme.shadowBrown.opacity(palette.isDark ? 0.10 : 0.06)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// 보드·띠에 쓰는 낮은 종이 그림자 (shadow.low)
    func paperShadowLow(dark: Bool) -> some View {
        self
            .shadow(color: (dark ? Color.black : Theme.shadowBrown).opacity(dark ? 0.35 : 0.10), radius: 0.5, y: 1)
            .shadow(color: (dark ? Color.black : Theme.shadowBrown).opacity(dark ? 0.45 : 0.14), radius: 4, y: 3)
    }
}
