import CloudKit
import CoreData
import Observation
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 애플 ID(iCloud) 로그인 상태와 동기화 진행을 지켜본다.
/// 별도 로그인 화면 없이, 기기에 로그인된 애플 ID로 CloudKit이 동기화한다.
@MainActor
@Observable
final class CloudStatus {
    /// pending: 동기화 전(아직 안 올라간 변경 있음) · syncing: 동기화 중 · upToDate: 동기화 완료
    enum State { case pending, syncing, upToDate, signedOut, localOnly, error }

    private(set) var state: State = .pending
    private(set) var lastError: String?
    /// 동시에 진행 중인 동기화 작업(설정·가져오기·내보내기). 모두 끝나야 "완료".
    private var running: Set<UUID> = []

    var message: String {
        switch state {
        case .pending:   "동기화 전"
        case .syncing:   "동기화 중…"
        case .upToDate:  "동기화 완료"
        case .signedOut: "iCloud에 로그인되어 있지 않아 이 기기에만 저장됩니다"
        case .localOnly: "iCloud 권한 없이 서명된 빌드라 이 기기에만 저장됩니다"
        case .error:     "동기화 오류" + (lastError.map { ": \($0)" } ?? "")
        }
    }

    var symbol: String {
        switch state {
        case .pending:   "icloud"
        case .syncing:   "arrow.triangle.2.circlepath.icloud"
        case .upToDate:  "checkmark.icloud"
        case .signedOut, .localOnly: "icloud.slash"
        case .error:     "exclamationmark.icloud"
        }
    }

    private var canSync: Bool { state != .signedOut && state != .localOnly }

    /// 사용자가 동기화 버튼을 눌러 기다리는 중 (아이콘 반응용)
    private(set) var isManualSyncing = false

    /// 지금 동기화.
    /// CloudKit+SwiftData에는 공개된 "지금 동기화" API가 없다. 대신 Core Data가 앱 활성화 알림을 받으면
    /// 가져오기·내보내기를 바로 시작하는 동작을 이용한다 (로그: "Beginning automated import - AppActivation").
    func syncNow(_ context: ModelContext) {
        guard canSync else { refreshAccount(); return }
        try? context.save()                         // 아직 저장 안 된 변경을 먼저 올리도록
        NSUbiquitousKeyValueStore.default.synchronize()  // 이름·폰트·색상 설정도 함께
        isManualSyncing = true
        state = .syncing
        #if os(macOS)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        #else
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
        // 할 일이 없거나 요청이 묶여서 이벤트가 안 오면 잠시 뒤 정리
        Task {
            try? await Task.sleep(for: .seconds(8))
            guard isManualSyncing else { return }
            isManualSyncing = false
            if running.isEmpty, state == .syncing { state = .upToDate }
        }
    }

    init() {
        guard CloudEnvironment.isCloudKitEntitled else {
            state = .localOnly
            return
        }
        // SwiftData는 내부적으로 NSPersistentCloudKitContainer를 쓰므로 이 이벤트가 온다.
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            MainActor.assumeIsolated { self?.handle(event) }
        }
        // 이 기기에서 저장했지만 아직 올라가기 전 → "동기화 전"
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.canSync, self.running.isEmpty else { return }
                self.state = .pending
            }
        }
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccount() }
        }
        refreshAccount()
    }

    func refreshAccount() {
        Task {
            let status = try? await CKContainer(identifier: CloudEnvironment.containerID).accountStatus()
            if status == .available {
                if !canSync { state = .pending }
            } else {
                state = .signedOut
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event?) {
        guard let event, canSync else { return }
        if event.endDate == nil {
            running.insert(event.identifier)
            state = .syncing
            return
        }
        running.remove(event.identifier)
        if !event.succeeded {
            state = .error
            lastError = event.error?.localizedDescription
            isManualSyncing = false
        } else if running.isEmpty {
            isManualSyncing = false
            // 이후 작업이 성공하면 이전 오류에서 회복된 것으로 본다
            state = .upToDate
            lastError = nil
        }
    }
}
