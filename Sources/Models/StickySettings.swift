import SwiftUI
import Observation

/// 사용자 설정. iCloud 키-값 저장소(NSUbiquitousKeyValueStore)에 저장되어
/// 같은 애플 ID의 맥·아이패드·아이폰에 자동으로 동기화된다.
@MainActor
@Observable
final class StickySettings {
    var font: StickyFont = .system { didSet { save(Key.font, font.rawValue) } }
    var weight: StickyWeight = .regular { didSet { save(Key.weight, weight.rawValue) } }
    var fontSize: Double = 17 { didSet { save(Key.fontSize, fontSize) } }
    var lineSpacing: Double = 4 { didSet { save(Key.lineSpacing, lineSpacing) } }
    var rowSpacing: Double = 6 { didSet { save(Key.rowSpacing, rowSpacing) } }
    var paper: PaperColor = .yellow { didSet { save(Key.paper, paper.rawValue) } }
    var authorName: String = "" { didSet { save(Key.authorName, authorName) } }

    var textFont: Font { font.font(size: fontSize, weight: weight.weight) }

    private enum Key {
        static let font = "font", weight = "weight", fontSize = "fontSize"
        static let lineSpacing = "lineSpacing", rowSpacing = "rowSpacing"
        static let paper = "paper", authorName = "authorName"
    }

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var isApplyingRemote = false

    init() {
        load()
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.load() }
        }
        // 실행 시 iCloud에서 최신 값을 당겨온다.
        cloud.synchronize()
    }

    private func value(_ key: String) -> Any? {
        cloud.object(forKey: key) ?? local.object(forKey: key)
    }

    private func load() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        if let v = value(Key.font) as? String, let f = StickyFont(rawValue: v) { font = f }
        if let v = value(Key.weight) as? String, let w = StickyWeight(rawValue: v) { weight = w }
        if let v = value(Key.fontSize) as? Double { fontSize = v }
        if let v = value(Key.lineSpacing) as? Double { lineSpacing = v }
        if let v = value(Key.rowSpacing) as? Double { rowSpacing = v }
        if let v = value(Key.paper) as? String, let p = PaperColor(rawValue: v) { paper = p }
        if let v = value(Key.authorName) as? String { authorName = v }
    }

    private func save(_ key: String, _ value: Any) {
        guard !isApplyingRemote else { return }
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
    }
}
