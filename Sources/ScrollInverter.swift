import ApplicationServices
import Foundation

// macOS has a single natural scrolling setting shared by every pointing device.
// With it on (right for the trackpad), this flips the direction of scroll events
// that come from a regular mouse wheel.
final class ScrollInverter {
    private static let naturalKey = "com.apple.swipescrolldirection" as CFString

    private var tap: CFMachPort?
    private(set) var naturalScrolling = ScrollInverter.readNaturalScrolling()
    var isEnabled = true

    var isRunning: Bool { tap != nil }
    var isInverting: Bool { isRunning && isEnabled && naturalScrolling }

    init() {
        // System Settings posts this when the toggle changes; the timer covers other writers.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("SwipeScrollDirectionDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.refreshNaturalScrolling() }
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refreshNaturalScrolling()
        }
    }

    // Needs Accessibility permission; returns false until it is granted.
    func start() -> Bool {
        if tap != nil { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                let inverter = Unmanaged<ScrollInverter>.fromOpaque(info!).takeUnretainedValue()
                inverter.handle(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        tap = port
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables taps that stall; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .scrollWheel where isEnabled && naturalScrolling && Self.isMouseWheel(event):
            Self.invert(event)
        default:
            break
        }
    }

    private func refreshNaturalScrolling() {
        naturalScrolling = Self.readNaturalScrolling()
    }

    // Natural scrolling is on by default when the key was never written.
    private static func readNaturalScrolling() -> Bool {
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let value = CFPreferencesCopyAppValue(naturalKey, kCFPreferencesAnyApplication)
        return (value as? Bool) ?? true
    }

    // Trackpads send continuous (pixel) events; a mouse wheel sends discrete line ticks.
    private static func isMouseWheel(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
    }

    private static func invert(_ event: CGEvent) {
        let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)
    }
}
