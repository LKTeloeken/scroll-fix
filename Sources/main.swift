// scroll-fix: natural scrolling on the trackpad, classic scrolling on the mouse.
//
// macOS has a single natural scrolling setting shared by every pointing device.
// Leave it on (right for the trackpad) and this daemon flips the direction of
// scroll events that come from a regular mouse wheel.

import ApplicationServices
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

func log(_ message: String) {
    print("[scroll-fix] \(message)")
}

let naturalKey = "com.apple.swipescrolldirection" as CFString

// Natural scrolling is on by default when the key was never written.
func readNaturalScrolling() -> Bool {
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    let value = CFPreferencesCopyAppValue(naturalKey, kCFPreferencesAnyApplication)
    return (value as? Bool) ?? true
}

var naturalScrolling = readNaturalScrolling()
var tap: CFMachPort?

// Trackpads send continuous (pixel) events; a mouse wheel sends discrete line ticks.
func isMouseWheel(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
}

func invert(_ event: CGEvent) {
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

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // The system disables taps that stall; turn it back on.
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    case .scrollWheel where naturalScrolling && isMouseWheel(event):
        invert(event)
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// Modifying events requires Accessibility permission. Ask once, then wait for it.
let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(promptOptions) {
    log("waiting for Accessibility permission")
    while !AXIsProcessTrusted() { sleep(2) }
}

let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
guard let port = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
) else {
    log("failed to create event tap")
    exit(1)
}
tap = port

CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, port, 0), .commonModes)
CGEvent.tapEnable(tap: port, enable: true)

func refreshNaturalScrolling() {
    let value = readNaturalScrolling()
    guard value != naturalScrolling else { return }
    naturalScrolling = value
    log("natural scrolling \(value ? "on, inverting mouse" : "off, passing mouse through")")
}

// System Settings posts this when the toggle changes; the timer covers other writers.
DistributedNotificationCenter.default().addObserver(
    forName: Notification.Name("SwipeScrollDirectionDidChangeNotification"),
    object: nil,
    queue: nil
) { _ in refreshNaturalScrolling() }
Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in refreshNaturalScrolling() }

log("running (natural scrolling \(naturalScrolling ? "on" : "off"))")
CFRunLoopRun()
