import SwiftUI
import SwiftData

/// 검색어 (일치하는 글자를 강조할 때 쓴다)
extension EnvironmentValues {
    @Entry var searchQuery = ""
}

/// 한 줄: [라벨 막대] 텍스트 · 고정 · 마감 ……… [체크박스]
/// 상태가 늘어도 골격은 그대로이고, 추가 정보는 텍스트 끝에 작게 붙는다.
struct NoteRow: View {
    @Bindable var item: NoteItem
    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(\.searchQuery) private var query
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool
    @State private var editing = false
    @State private var showDue = false
    /// 펜 취소선 진행 (0…1)
    @State private var strike: CGFloat

    init(item: NoteItem) {
        self.item = item
        _strike = State(initialValue: item.isDone ? 1 : 0)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LineBox(font: settings.textFont) { LabelPill(label: $item.label) }
                .opacity(item.isDone ? 0.4 : 1)

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            LineBox(font: settings.textFont) {
                CheckBox(isOn: item.isDone, size: settings.fontSize, action: toggle)
            }
        }
        .contentShape(Rectangle())
        .contextMenu { menu }
        #if os(macOS)
        .popover(isPresented: $showDue, arrowEdge: .trailing) {
            DueEditor(item: item) { showDue = false }
                .environment(\.palette, Palette(paperColor: palette.paperColor, isDark: false))
        }
        #else
        .sheet(isPresented: $showDue) {
            NavigationStack {
                DueEditor(item: item) { showDue = false }
            }
            .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(trigger: item.isDone) { _, done in done ? .success : nil }
        #endif
        .onChange(of: item.isDone) { _, done in
            // 다른 기기에서 바뀐 경우 등: 애니메이션 없이 맞춘다
            let target: CGFloat = done ? 1 : 0
            if strike != target { strike = target }
        }
    }

    // MARK: 본문 — 편집 중이면 입력칸, 아니면 한 덩어리 글자(고정·마감 표시가 글자 뒤에 이어 붙는다)

    @ViewBuilder
    private var content: some View {
        if editing && !item.isDone {
            TextField("", text: $item.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .lineSpacing(settings.lineSpacing)
                .foregroundStyle(palette.ink)
                .tint(palette.caret)
                .focused($focused)
                .onSubmit { focused = false }
                .onAppear { DispatchQueue.main.async { focused = true } }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { finishEditing() }
                }
        } else {
            displayText
                .lineSpacing(settings.lineSpacing)
                .overlay(alignment: .leading) { strikeOverlay }
                .opacity(item.isDone ? 0.4 : 1)
                .onTapGesture { if !item.isDone { editing = true } }
                .accessibilityAddTraits(item.isDone ? [] : .isButton)
        }
    }

    /// 텍스트 + (고정 핀) + (마감)
    private var displayText: Text {
        var text = Text(highlighted).font(settings.textFont).foregroundStyle(palette.ink)
        let small = settings.fontSize * 0.78
        if item.isPinned && !item.isDone {
            text = text + Text("  ") + Text(Image(systemName: "pin.fill"))
                .font(.system(size: small * 0.85))
                .foregroundStyle(palette.secondary)
        }
        if let due = item.dueDate, !item.isDone {
            let info = DueInfo(due)
            let color: Color = switch info.state {
            case .overdue: palette.overdue
            case .today: palette.ink.opacity(0.78)
            case .future: palette.secondary
            }
            let icon = info.state == .overdue ? "exclamationmark.circle.fill" : "clock"
            let weight: Font.Weight = info.state == .future ? .medium : .semibold
            text = text + Text("  ")
                + Text(Image(systemName: icon)).font(.system(size: small * 0.9, weight: weight)).foregroundStyle(color)
                + Text(" \(info.text)").font(.system(size: small, weight: weight)).foregroundStyle(color)
        }
        return text
    }

    /// 검색어와 일치하는 부분을 굵게 + 옅은 잉크 바탕으로
    private var highlighted: AttributedString {
        var attr = AttributedString(item.text)
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return attr }
        var searchStart = attr.startIndex
        while searchStart < attr.endIndex,
              let range = attr[searchStart...].range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            attr[range].backgroundColor = palette.ink.opacity(0.14)
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return attr
    }

    /// 펜으로 긋듯 왼→오로 지나가는 취소선. 같은 글자를 투명하게 겹쳐 취소선만 보이게 한 뒤 폭으로 가린다.
    private var strikeOverlay: some View {
        Text(item.text)
            .font(settings.textFont)
            .lineSpacing(settings.lineSpacing)
            .foregroundStyle(.clear)
            .strikethrough(true, color: palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle().frame(width: geo.size.width * strike)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: 메뉴 (우클릭 · 길게 누르기)

    @ViewBuilder
    private var menu: some View {
        Button(item.isDone ? "완료 취소" : "완료", action: toggle)
        if !item.isDone {
            Button(item.isPinned ? "고정 해제" : "맨 위에 고정") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { item.isPinned.toggle() }
            }
            Button(item.dueDate == nil ? "마감일…" : "마감일 바꾸기…") { showDue = true }
            Button("편집") { editing = true }
        }
        Picker("라벨", selection: $item.label) {
            ForEach(NoteLabel.allCases) { label in
                Text(label.title).tag(label)
            }
        }
        Divider()
        Button("삭제", role: .destructive) {
            withAnimation { context.delete(item) }
        }
    }

    // MARK: 체크 — 체크 그리기(220ms) → 펜 취소선(80ms 뒤 320ms) → 600ms 머문 뒤 가라앉기

    private func toggle() {
        let done = !item.isDone
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                item.setDone(done)
                strike = done ? 1 : 0
            }
        } else if done {
            withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.22)) { item.setDone(true) }
            withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 0.32).delay(0.08)) { strike = 1 }
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                item.setDone(false)
                strike = 0
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(done ? 600 : 250))
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.86)) {
                item.settlePosition()
            }
        }
    }

    private func finishEditing() {
        editing = false
        if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation { context.delete(item) }
        }
    }
}

/// 첫 줄과 같은 높이의 칸을 만들고 그 가운데에 내용을 둔다.
/// 숨긴 글자가 기준선(baseline)을 제공하므로 .firstTextBaseline 정렬에서 텍스트 줄과 정확히 맞는다.
struct LineBox<Content: View>: View {
    var font: Font
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Text("가").font(font).hidden()
            content
        }
    }
}

/// 체크박스: 크기 = 글자 × 1.3, 모서리 30%. 채움 = 잉크 78%, 체크 = 종이색 → 7색 모두에서 대비 확보.
struct CheckBox: View {
    var isOn: Bool
    var size: Double
    var action: () -> Void
    @Environment(\.palette) private var palette

    private var side: CGFloat { max(14, size * 1.05) }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                    .strokeBorder(palette.ink.opacity(0.55), lineWidth: 1.3)
                    .opacity(isOn ? 0 : 1)
                RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                    .fill(palette.checkFill)
                    .opacity(isOn ? 1 : 0)
                CheckMark()
                    .trim(from: 0, to: isOn ? 1 : 0)
                    .stroke(palette.paper, style: StrokeStyle(lineWidth: max(1.6, side * 0.12), lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            #if os(iOS)
            .frame(width: 44, height: 44)
            .padding(-12)
            #endif
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(isOn ? "완료됨" : "미완료")
    }
}

/// 체크 표시 (왼→오로 그려진다)
struct CheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.68))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.34))
        return p
    }
}

/// 누르는 동안 0.9배
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 텍스트 앞의 컬러 라벨 막대(5×14). 누르면 색을 고른다.
/// "색상 없이 구별"이 켜져 있으면 막대 대신 모양 기호.
struct LabelPill: View {
    @Binding var label: NoteLabel
    var placeholderPlus = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    var body: some View {
        Menu {
            Picker("라벨", selection: $label) {
                ForEach(NoteLabel.allCases) { l in
                    Label(l.title, systemImage: l == .none ? "circle.dashed" : "circle.fill")
                        .tint(palette.label(l))
                        .tag(l)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Group {
                if placeholderPlus && label == .none {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .frame(width: 12)
                } else if noColor && label != .none {
                    Image(systemName: label.shapeSymbol)
                        .font(.system(size: 8))
                        .foregroundStyle(palette.label(label))
                        .frame(width: 8)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(label == .none ? Color.clear : palette.label(label))
                        .frame(width: 5, height: 14)
                }
            }
            .contentShape(Rectangle().inset(by: -6))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("라벨: \(label.title)")
    }
}

// MARK: - 마감일 편집 (맥: 줄에 붙은 팝오버 · iOS: 시트)

struct DueEditor: View {
    @Bindable var item: NoteItem
    var close: () -> Void
    @State private var date: Date
    @State private var remind: RemindOption

    init(item: NoteItem, close: @escaping () -> Void) {
        self.item = item
        self.close = close
        let cal = Calendar.current
        let nextHour = cal.date(bySettingHour: (cal.component(.hour, from: .now) + 1) % 24, minute: 0, second: 0, of: .now) ?? .now
        _date = State(initialValue: item.dueDate ?? nextHour)
        _remind = State(initialValue: item.dueDate == nil ? .min10 : (RemindOption(rawValue: item.remindMinutes) ?? .none))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                #if os(macOS)
                Text("마감일").font(.headline)
                Spacer()
                #endif
                Text(item.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(DueQuickPick.allCases) { pick in
                    Button {
                        date = pick.date()
                        save()
                    } label: {
                        HStack {
                            Text(pick.title)
                            Spacer(minLength: 4)
                            Text(pick.detail()).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            DatePicker("날짜", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
            DatePicker("시간", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
            LabeledContent("알림") {
                Picker("알림", selection: $remind) {
                    ForEach(RemindOption.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Divider()
            HStack {
                if item.dueDate != nil {
                    Button("마감 지우기", role: .destructive) {
                        item.dueDate = nil
                        item.remindMinutes = -1
                        close()
                    }
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("완료", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        // 앱 글자가 모두 한국어이므로 날짜·시간도 한국어로 ("2026. 10. 17.", "오후 3:00")
        .environment(\.locale, Locale(identifier: "ko_KR"))
        #if os(macOS)
        .frame(width: 320)
        #else
        .navigationTitle("마감일")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("취소", action: close) }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        #endif
    }

    private func save() {
        item.dueDate = date
        item.remindMinutes = remind.rawValue
        if remind != .none { Reminders.requestAuthorization() }
        close()
    }
}
