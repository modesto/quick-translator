import QuickTranslatorCore
import ServiceManagement

final class MainAppLoginItem: LoginItemService {
    private let service = SMAppService.mainApp

    var status: LoginItemStatus {
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .disabled
        }
    }

    func register() throws { try service.register() }

    func unregister() throws { try service.unregister() }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
