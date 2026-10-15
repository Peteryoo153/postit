import CloudKit
import CoreData
import Observation

/// 애플 ID(iCloud) 로그인 상태와 동기화 진행을 지켜본다.
/// 별도 로그인 화면 없이, 기기에 로그인된 애플 ID로 CloudKit이 동기화한다.
@MainActor
@Observable
final class CloudStatus {
    enum State { case checking, syncing, upToDate, signedOut, error }

    private(set) var state: State = .checking

    var message: String? {
        switch state {
        case .checking, .upToDate: nil
        case .syncing:   "iCloud 동기화 중…"
        case .signedOut: "iCloud에 로그인되어 있지 않아 이 기기에만 저장됩니다"
        case .error:     "iCloud 동기화 오류"
        }
    }

    var symbol: String {
        switch state {
        case .syncing:   "arrow.triangle.2.circlepath.icloud"
        case .signedOut: "icloud.slash"
        case .error:     "exclamationmark.icloud"
        default:         "checkmark.icloud"
        }
    }

    private let containerID: String

    init(containerID: String) {
        self.containerID = containerID
        // SwiftData는 내부적으로 NSPersistentCloudKitContainer를 쓰므로 이 이벤트가 온다.
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            MainActor.assumeIsolated { self?.handle(event) }
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
            let status = try? await CKContainer(identifier: containerID).accountStatus()
            state = (status == .available) ? .syncing : .signedOut
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event?) {
        guard let event, state != .signedOut else { return }
        if event.endDate == nil {
            state = .syncing
        } else {
            state = event.succeeded ? .upToDate : .error
        }
    }
}
