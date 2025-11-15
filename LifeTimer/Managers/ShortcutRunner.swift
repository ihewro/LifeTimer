import Foundation
#if os(macOS)
import AppKit
#endif

enum ShortcutEvent: String {
    case start
    case stop
    case complete
}

class ShortcutRunner {
    static let shared = ShortcutRunner()

    private let userDefaults = UserDefaults.standard
    private let enabledKey = "ShortcutsEnabled"

    private var lastRunTimestamps: [ShortcutEvent: TimeInterval] = [:]

    func runIfEnabled(for event: ShortcutEvent, mode: TimerMode?) {
        if !userDefaults.bool(forKey: enabledKey) { return }

        let now = Date().timeIntervalSince1970
        if let last = lastRunTimestamps[event], now - last < 0.8 { return }
        lastRunTimestamps[event] = now

        let input = command(for: event, mode: mode)
        guard let input else { return }
        run(name: "LifeTimer", input: input)
    }

    private func command(for event: ShortcutEvent, mode: TimerMode?) -> String? {
        switch event {
        case .start:
            switch mode {
            case .singlePomodoro?:
                return "tomato"
            case .countUp?:
                return "timing"
            case .pureRest?:
                return "rest"
            case .custom?:
                return "timing"
            case nil:
                return nil
            }
        case .stop:
            return "cancel"
        case .complete:
            return "complete"
        }
    }

    private func run(name: String, input: String) {
        #if os(macOS)
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "input", value: input)
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}