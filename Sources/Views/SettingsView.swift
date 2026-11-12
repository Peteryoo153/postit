import SwiftUI

/// 폰트 · 크기 · 두께 · 간격 · 종이 색상. 모든 값은 iCloud로 다른 기기와 동기화된다.
struct SettingsView: View {
    @Environment(StickySettings.self) private var settings
    #if os(macOS)
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @State private var launchAtLogin = LoginItem.isEnabled
    @AppStorage("menuBarIcon") private var menuBarIcon = true
    #endif
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("새 포스트잇 기본 색") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 10) {
                    ForEach(PaperColor.allCases) { paper in
                        Button {
                            s.paper = paper
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(paper.color(dark: colorScheme == .dark))
                                .frame(width: 30, height: 30)
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                .overlay {
                                    if s.paper == paper {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Palette(paperColor: paper, isDark: colorScheme == .dark).ink)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(paper.title)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("글꼴") {
                Picker("폰트", selection: $s.font) {
                    ForEach(StickyFont.allCases) { Text($0.title).tag($0) }
                }
                Picker("두께", selection: $s.weight) {
                    ForEach(StickyWeight.allCases) { Text($0.title).tag($0) }
                }
                slider("크기", value: $s.fontSize, in: 11...32, unit: "pt")
                slider("줄 간격", value: $s.lineSpacing, in: 0...16, unit: "pt")
                slider("항목 간격", value: $s.rowSpacing, in: 0...24, unit: "pt")
            }

            Section("미리보기") {
                let palette = Palette(paperColor: s.paper, isDark: colorScheme == .dark)
                VStack(alignment: .leading, spacing: s.rowSpacing) {
                    Text("Today").font(.system(size: s.fontSize * 1.07, weight: .bold))
                    Text("주보 원고 — 광고 3건 확인").font(s.textFont)
                    Text("금요 기도회 찬양 순서 보내기").font(s.textFont)
                }
                .lineSpacing(s.lineSpacing)
                .foregroundStyle(palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background {
                    PaperSurface(texture: s.paperTexture).environment(\.palette, palette)
                }
                .clipShape(RoundedRectangle(cornerRadius: s.cornerRadius * 0.5, style: .continuous))
            }

            Section("화면") {
                Picker("모드", selection: $s.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("종이 질감과 그림자", isOn: $s.paperTexture)
            }

            #if os(macOS)
            Section("모양") {
                slider("모서리", value: $s.cornerRadius, in: 0...32, unit: "pt")
                HStack {
                    Text("각지게").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("둥글게").font(.caption).foregroundStyle(.secondary)
                }
            }
            #endif

            Section("작성자") {
                TextField("포스트잇 하단에 표시할 이름", text: $s.authorName)
            }

            #if os(macOS)
            Section("창") {
                Toggle("항상 다른 창 위에 띄우기", isOn: $alwaysOnTop)
                Toggle("메뉴 막대에 빠른 입력 아이콘", isOn: $menuBarIcon)
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { launchAtLogin },
                    set: { LoginItem.set($0); launchAtLogin = LoginItem.isEnabled }
                ))
                LabeledContent("어디서나 포스트잇 열기", value: GlobalHotKey.displayName)
                LabeledContent("새 포스트잇", value: "⌘N (최대 \(StickyStore.maxOpen)장)")
                LabeledContent("검색", value: "⌘F")
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("설정")
        #if os(macOS)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    private func slider(_ title: String, value: Binding<Double>,
                        in range: ClosedRange<Double>, unit: String) -> some View {
        LabeledContent {
            HStack {
                Slider(value: value, in: range, step: 1)
                Text("\(Int(value.wrappedValue))\(unit)")
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
        }
    }
}
