#if os(iOS)
import SwiftUI
import SwiftData

/// 아이폰 = 한 장 + 옆으로 넘기기. 아이패드 = 보드(여러 장 나란히), 좁은 창이면 아이폰처럼.
struct IOSRoot: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Sticky.createdAt) private var stickies: [Sticky]
    /// 지금 보고 있는 포스트잇 (기기마다 따로)
    @AppStorage("currentSticky") private var currentSticky = StickyStore.defaultID.uuidString

    var body: some View {
        GeometryReader { geo in
            if sizeClass == .regular && geo.size.width >= 520 {
                BoardView(stickies: Array(stickies.prefix(StickyStore.maxOpen)))
            } else {
                PagerView(stickies: Array(stickies.prefix(StickyStore.maxOpen)), current: $currentSticky)
            }
        }
    }
}

// MARK: - 아이폰: 옆으로 넘겨 장 바꾸기

struct PagerView: View {
    let stickies: [Sticky]
    @Binding var current: String
    @Environment(\.colorScheme) private var colorScheme

    private var selection: Binding<UUID> {
        Binding(
            get: {
                let id = UUID(uuidString: current) ?? StickyStore.defaultID
                return stickies.contains { $0.id == id } ? id : (stickies.first?.id ?? StickyStore.defaultID)
            },
            set: { current = $0.uuidString }
        )
    }

    var body: some View {
        // 종이가 시계·홈 막대 자리까지 닿도록 TabView는 화면 끝까지, 글자는 안전 영역 안쪽으로
        GeometryReader { geo in
            TabView(selection: selection) {
                ForEach(Array(stickies.enumerated()), id: \.element.id) { index, sticky in
                    StickyView(stickyID: sticky.id, layout: .page, safeInsets: geo.safeAreaInsets,
                               pageIndex: index, pageCount: stickies.count) { current = $0.uuidString }
                        .tag(sticky.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // 장 사이 틈 = 어두운 책상
            .background(colorScheme == .dark ? Theme.hex(0x121211) : Theme.hex(0x2A2926))
            .ignoresSafeArea(.container)
        }
    }
}

// MARK: - 아이패드: 벽에 붙인 포스트잇 보드

struct BoardView: View {
    let stickies: [Sticky]
    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<NoteItem> { $0.isDone == false }) private var openItems: [NoteItem]
    @State private var zoomed: UUID?
    @State private var searching = false
    @State private var query = ""
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool
    @Namespace private var zoom

    private var isDark: Bool { colorScheme == .dark }
    private var desk: Color { isDark ? Theme.hex(0x1C1B19) : Theme.hex(0xE4E1DA) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let zoomed, stickies.contains(where: { $0.id == zoomed }) {
                zoomedView(zoomed)
            } else {
                grid
            }
        }
        .background(desk.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView().toolbar { Button("완료") { showSettings = false } }
            }
        }
    }

    // MARK: 위쪽 한 줄: Today · 날짜 · 남은 일 | 검색 · 추가 · 더보기

    private var topBar: some View {
        HStack(spacing: 14) {
            if zoomed != nil {
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { zoomed = nil }
                } label: {
                    Label("보드", systemImage: "chevron.left")
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
            }
            Text("Today").font(.system(size: 26, weight: .bold))
            Text("\(DayHeader.format(.now)) · 남은 일 \(openItems.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if searching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("모든 포스트잇에서 찾기", text: $query)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .frame(width: 220)
                    Button {
                        closeSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
            } else {
                roundButton("magnifyingglass", label: "검색") {
                    searching = true
                    DispatchQueue.main.async { searchFocused = true }
                }
                .keyboardShortcut("f")
            }

            roundButton("plus", label: "새 포스트잇") {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                    _ = StickyStore.create(in: context, paper: settings.paper)
                }
            }
            .disabled(stickies.count >= StickyStore.maxOpen)
            .help(stickies.count >= StickyStore.maxOpen ? "최대 \(StickyStore.maxOpen)장" : "새 포스트잇")

            Menu {
                Button("설정", systemImage: "gearshape") { showSettings = true }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 40, height: 40)
                    .background(.thinMaterial, in: Circle())
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 40, height: 40)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func closeSearch() {
        searching = false
        query = ""
    }

    // MARK: 장 수에 따른 배치: 열을 먼저 늘리고 줄은 나중에. 한 장 폭이 260pt 아래면 줄을 하나 더.

    static func columns(count: Int, size: CGSize) -> Int {
        guard count > 0 else { return 1 }
        let landscape = size.width > size.height
        var cols: Int
        if size.width < 800 {
            cols = min(2, count)
        } else if landscape {
            cols = count <= 4 ? count : 3
        } else {
            cols = count == 1 ? 1 : 2
        }
        while cols > 1 && (size.width - CGFloat(cols + 1) * 16) / CGFloat(cols) < 260 { cols -= 1 }
        return cols
    }

    private var grid: some View {
        GeometryReader { geo in
            let gap: CGFloat = 16
            let cols = Self.columns(count: stickies.count, size: geo.size)
            let rows = Int(ceil(Double(max(stickies.count, 1)) / Double(cols)))
            let width = (geo.size.width - gap * CGFloat(cols + 1)) / CGFloat(cols)
            let height = (geo.size.height - gap * CGFloat(rows + 1)) / CGFloat(rows)
            let single = stickies.count == 1

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<cols, id: \.self) { col in
                            let index = row * cols + col
                            if index < stickies.count {
                                card(stickies[index])
                                    .frame(width: single ? min(640, width) : width, height: height)
                            } else {
                                Color.clear.frame(width: width, height: height)
                            }
                        }
                    }
                }
            }
            .padding(gap)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func card(_ sticky: Sticky) -> some View {
        StickyView(stickyID: sticky.id, layout: .card,
                   externalQuery: searching ? query : nil,
                   onZoom: {
                       withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { zoomed = sticky.id }
                   })
            .matchedGeometryEffect(id: sticky.id, in: zoom)
            .paperShadowLow(dark: isDark)
    }

    // MARK: 한 장 크게 보기 — 나머지는 오른쪽에 접힌 띠로

    private func zoomedView(_ id: UUID) -> some View {
        HStack(alignment: .top, spacing: 16) {
            StickyView(stickyID: id, layout: .card, externalQuery: searching ? query : nil)
                .matchedGeometryEffect(id: id, in: zoom)
                .paperShadowLow(dark: isDark)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("다른 포스트잇")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(stickies.filter { $0.id != id }) { s in
                    CollapsedStrip(stickyID: s.id, title: s.title.isEmpty ? s.paper.title : s.title, paper: s.paper)
                        .frame(height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: min(settings.cornerRadius, 12), style: .continuous))
                        .paperShadowLow(dark: isDark)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) { zoomed = s.id }
                        }
                }
                Spacer()
            }
            .frame(width: 240)
        }
        .padding(16)
    }
}
#endif
