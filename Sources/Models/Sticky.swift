import Foundation
import SwiftData

/// 포스트잇 한 장. 이름·종이 색·열림 여부는 iCloud로 동기화된다.
/// 그래서 한 맥에서 열어 둔 포스트잇은 다른 맥에서도 열린다.
/// 창 위치·크기·접힘은 화면마다 달라서 기기마다 따로 기억한다(OpenStickies).
@Model
final class Sticky {
    var id: UUID = UUID()
    var title: String = ""
    var paperRaw: String = PaperColor.yellow.rawValue
    var createdAt: Date = Date.now
    /// 맥에서 창으로 열려 있는지 (모든 맥이 같은 포스트잇을 연다)
    var isOpen: Bool = true

    init(id: UUID = UUID(), title: String = "", paper: PaperColor = .yellow) {
        self.id = id
        self.title = title
        self.paperRaw = paper.rawValue
        self.createdAt = .now
    }

    var paper: PaperColor {
        get { PaperColor(rawValue: paperRaw) ?? .yellow }
        set { paperRaw = newValue.rawValue }
    }
}

@MainActor
enum StickyStore {
    /// 처음부터 있던 포스트잇. 모든 기기에서 같은 id를 써야 동기화 후 하나로 합쳐진다.
    nonisolated static let defaultID = UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!
    nonisolated static let maxOpen = 6

    /// 기본 포스트잇을 보장하고, 예전 항목(포스트잇 구분 없음)을 기본 포스트잇으로 옮긴다.
    /// 여러 기기가 각자 기본 포스트잇을 만들어 동기화로 겹치면 가장 오래된 것만 남긴다.
    static func prepare(in context: ModelContext, defaultPaper: PaperColor) {
        let id = defaultID
        let defaults = (try? context.fetch(FetchDescriptor<Sticky>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\.createdAt)]
        ))) ?? []
        if defaults.isEmpty {
            context.insert(Sticky(id: id, paper: defaultPaper))
        } else {
            for extra in defaults.dropFirst() { context.delete(extra) }
        }

        let orphans = (try? context.fetch(FetchDescriptor<NoteItem>(
            predicate: #Predicate { $0.stickyID == nil }
        ))) ?? []
        for item in orphans { item.stickyID = id }
        try? context.save()
    }

    /// 열어 둔 포스트잇 (오래된 순, 최대 maxOpen장)
    static func openIDs(in context: ModelContext) -> [UUID] {
        Array(all(in: context).filter(\.isOpen).prefix(maxOpen).map(\.id))
    }

    static func setOpen(_ id: UUID, _ open: Bool, in context: ModelContext) {
        withoutUndo(context) {
            guard let sticky = all(in: context).first(where: { $0.id == id }), sticky.isOpen != open else { return }
            sticky.isOpen = open
            try? context.save()
        }
    }

    static func all(in context: ModelContext) -> [Sticky] {
        (try? context.fetch(FetchDescriptor<Sticky>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// 포스트잇을 만들고 지우는 일은 ⌘Z 대상이 아니다 (되돌리면 창이 사라지므로)
    private static func withoutUndo<T>(_ context: ModelContext, _ body: () -> T) -> T {
        let undo = context.undoManager
        context.undoManager = nil
        defer { context.undoManager = undo }
        return body()
    }

    static func create(in context: ModelContext, paper: PaperColor) -> Sticky {
        withoutUndo(context) { makeSticky(in: context, paper: paper) }
    }

    private static func makeSticky(in context: ModelContext, paper: PaperColor) -> Sticky {
        // 이미 있는 색과 겹치지 않는 색을 고른다
        let used = Set(all(in: context).map(\.paper))
        let color = used.contains(paper) ? (PaperColor.allCases.first { !used.contains($0) } ?? paper) : paper
        let sticky = Sticky(paper: color)
        context.insert(sticky)
        try? context.save()
        return sticky
    }

    /// 포스트잇과 그 안의 할 일을 모두 지운다. 기본 포스트잇은 지울 수 없다.
    static func delete(_ stickyID: UUID, in context: ModelContext) {
        guard stickyID != defaultID else { return }
        withoutUndo(context) {
            try? context.delete(model: NoteItem.self, where: #Predicate { $0.stickyID == stickyID })
            try? context.delete(model: Sticky.self, where: #Predicate { $0.id == stickyID })
            try? context.save()
        }
    }
}

/// 이 기기에서 열어 둔 포스트잇 목록 (동기화하지 않음).
enum OpenStickies {
    private static let key = "openStickies"

    static var ids: [UUID] {
        get { (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: key) }
    }

    static func collapsedKey(_ id: UUID) -> String { "collapsed.\(id.uuidString)" }
    static func expandedHeightKey(_ id: UUID) -> String { "expandedHeight.\(id.uuidString)" }
}
