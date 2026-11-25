import Testing
@testable import QuickTranslatorCore

private struct LoginItemFailure: Error {}

private final class FakeLoginItemService: LoginItemService {
    var status: LoginItemStatus
    var calls: [String] = []
    var fails = false

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {
        calls.append("register")
        if fails { throw LoginItemFailure() }
        status = .enabled
    }

    func unregister() throws {
        calls.append("unregister")
        if fails { throw LoginItemFailure() }
        status = .disabled
    }
}

@Suite("LaunchAtLogin")
struct LaunchAtLoginTests {
    @Test("registers the app when turned on")
    func turnOn() throws {
        let service = FakeLoginItemService(status: .disabled)
        let launch = LaunchAtLogin(service: service)
        try launch.setEnabled(true)
        #expect(service.calls == ["register"])
        #expect(launch.isEnabled)
    }

    @Test("unregisters the app when turned off")
    func turnOff() throws {
        let service = FakeLoginItemService(status: .enabled)
        let launch = LaunchAtLogin(service: service)
        try launch.setEnabled(false)
        #expect(service.calls == ["unregister"])
        #expect(!launch.isEnabled)
    }

    @Test("does nothing when the state does not change")
    func unchanged() throws {
        let service = FakeLoginItemService(status: .enabled)
        try LaunchAtLogin(service: service).setEnabled(true)
        #expect(service.calls.isEmpty)
    }

    @Test("counts as on while it waits for approval in System Settings")
    func waitingForApproval() throws {
        let service = FakeLoginItemService(status: .requiresApproval)
        let launch = LaunchAtLogin(service: service)
        #expect(launch.isEnabled)
        #expect(launch.needsApproval)
        try launch.setEnabled(false)
        #expect(service.calls == ["unregister"])
    }

    @Test("reports a failure and keeps the previous state")
    func failure() {
        let service = FakeLoginItemService(status: .disabled)
        service.fails = true
        let launch = LaunchAtLogin(service: service)
        #expect(throws: LoginItemFailure.self) { try launch.setEnabled(true) }
        #expect(!launch.isEnabled)
    }
}
