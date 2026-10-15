import SwiftUI

/// 폰트 · 크기 · 두께 · 간격 · 종이 색상. 모든 값은 iCloud로 다른 기기와 동기화된다.
struct SettingsView: View {
    @Environment(StickySettings.self) private var settings
    #if os(macOS)
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    #endif

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("종이") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34))], spacing: 10) {
                    ForEach(PaperColor.allCases) { paper in
                        Button {
                            s.paper = paper
                        } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(paper.color)
                                .frame(width: 30, height: 30)
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                                .overlay {
                                    if s.paper == paper {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Theme.ink)
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
                Text("http://api.url/1.0/post\n//main method for post")
                    .font(s.textFont)
                    .lineSpacing(s.lineSpacing)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(s.paper.color, in: RoundedRectangle(cornerRadius: s.cornerRadius * 0.5))
                    .environment(\.colorScheme, .light)
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
