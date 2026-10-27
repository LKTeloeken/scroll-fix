# ScrollFix

Natural scrolling on the trackpad, classic scrolling on the mouse.

macOS has a single natural scrolling setting shared by every pointing device.
ScrollFix is a tiny menu bar app: keep natural scrolling **on** in System
Settings and it flips the direction of events that come from a mouse wheel.
Both devices work correctly at the same time, with nothing to toggle when you
switch.

## Install

With Homebrew:

```sh
brew tap LKTeloeken/scroll-fix https://github.com/LKTeloeken/scroll-fix
brew install --cask scroll-fix
```

From source (needs the Xcode Command Line Tools):

```sh
git clone https://github.com/LKTeloeken/scroll-fix
cd scroll-fix
make install
```

Then:

1. Allow ScrollFix in **System Settings → Privacy & Security → Accessibility**.
   It starts working a couple of seconds later, no restart needed.
2. Turn **natural scrolling on** in System Settings → Trackpad.

ScrollFix adds itself to the login items on first launch. The menu bar icon
lets you pause it, turn off opening at login, or quit.

## How it works

A `CGEventTap` watches scroll events. Trackpads send continuous (pixel)
events, a mouse wheel sends discrete line ticks; only the discrete ones are
inverted. If natural scrolling is off in the system, ScrollFix does nothing.

Mice that fake smooth scrolling (Magic Mouse, some vendor drivers) send
continuous events too, so they are treated like a trackpad.

## Notes

- The app is only ad-hoc signed. macOS ties the Accessibility grant to the
  signature, so after an update or rebuild you may need to remove ScrollFix
  from the Accessibility list and allow it again.
- Releases are built by GitHub Actions when a `v*` tag is pushed.

## Uninstall

```sh
brew uninstall --cask scroll-fix   # or: make uninstall
```
