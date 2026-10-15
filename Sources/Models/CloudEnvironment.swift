import Foundation
#if os(macOS)
import Security
#endif

/// 이 빌드가 iCloud(CloudKit) 권한을 갖고 서명되었는지.
/// 권한 없이 CloudKit 컨테이너를 만들면 시스템이 앱을 즉시 종료시키므로 먼저 확인한다.
enum CloudEnvironment {
    static let containerID = "iCloud.com.peter.postit"

    static let isCloudKitEntitled: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(
                  task, "com.apple.developer.icloud-container-identifiers" as CFString, nil),
              let ids = value as? [String]
        else { return false }
        return ids.contains(containerID)
        #else
        // iOS는 서명 없이 기기에서 실행할 수 없고, 시뮬레이터도 프로필로 권한이 붙는다.
        return true
        #endif
    }()
}
