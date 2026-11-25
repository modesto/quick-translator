public enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case requiresApproval
    case disabled
}

public protocol LoginItemService: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

public final class LaunchAtLogin {
    private let service: LoginItemService

    public init(service: LoginItemService) {
        self.service = service
    }

    public var isEnabled: Bool { service.status != .disabled }

    public var needsApproval: Bool { service.status == .requiresApproval }

    public func setEnabled(_ enabled: Bool) throws {
        guard enabled != isEnabled else { return }
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}
