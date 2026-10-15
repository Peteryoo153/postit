import SwiftUI
import SwiftData

/// 한 줄: [라벨] 텍스트 ............ [체크박스]
struct NoteRow: View {
    @Bindable var item: NoteItem
    @Environment(StickySettings.self) private var settings
    @Environment(\.modelContext) private var context
    @FocusState private var editing: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            LabelPill(label: $item.label)

            TextField("", text: $item.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(settings.textFont)
                .lineSpacing(settings.lineSpacing)
                .foregroundStyle(Theme.ink)
                .strikethrough(item.isDone, color: Theme.ink.opacity(0.6))
                .opacity(item.isDone ? 0.4 : 1)
                .focused($editing)
                .onChange(of: editing) { _, isEditing in
                    if !isEditing { deleteIfEmpty() }
                }

            CheckBox(isOn: item.isDone, size: settings.fontSize) { toggle() }
        }
        .contextMenu {
            Picker("라벨", selection: $item.label) {
                ForEach(NoteLabel.allCases) { label in
                    Text(label.title).tag(label)
                }
            }
            Button(item.isDone ? "완료 취소" : "완료", action: toggle)
            Divider()
            Button("삭제", role: .destructive) {
                withAnimation { context.delete(item) }
            }
        }
    }

    private func toggle() {
        withAnimation(.easeOut(duration: 0.2)) { item.setDone(!item.isDone) }
        // 밑줄·흐림을 잠깐 보여준 뒤 아래(또는 위)로 이동
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.spring(duration: 0.4)) { item.settlePosition() }
        }
    }

    private func deleteIfEmpty() {
        if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            withAnimation { context.delete(item) }
        }
    }
}

struct CheckBox: View {
    var isOn: Bool
    var size: Double
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: size * 0.95, weight: .regular))
                .foregroundStyle(Theme.ink.opacity(isOn ? 0.45 : 0.7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "완료됨" : "미완료")
    }
}

/// 텍스트 앞의 컬러 라벨. 누르면 색을 고른다.
struct LabelPill: View {
    @Binding var label: NoteLabel

    var body: some View {
        Menu {
            Picker("라벨", selection: $label) {
                ForEach(NoteLabel.allCases) { l in
                    Label(l.title, systemImage: l == .none ? "circle.dashed" : "circle.fill")
                        .tint(l.color)
                        .tag(l)
                }
            }
            .pickerStyle(.inline)
        } label: {
            RoundedRectangle(cornerRadius: 2)
                .fill(label == .none ? Theme.ink.opacity(0.12) : label.color)
                .frame(width: 6, height: 14)
                .padding(.vertical, 2)
                .contentShape(Rectangle().inset(by: -6))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("라벨: \(label.title)")
    }
}
