# Grigrid

A minimal macOS menu-bar grid window manager, modeled after WindowGrid for Windows. You snap a window to a rectangle of grid cells while you drag it. It's pure Swift and AppKit with no dependencies, and it needs macOS 13 or later.

## The gesture

1. Start dragging a window by its title bar with the **left** button, and keep holding it.
2. Press and hold the **right** button. A grid overlay appears on the screen under the cursor, and the cell under the cursor (the anchor) follows it.
3. Release the **right** button to fix the anchor. Moving the cursor now grows a rectangle from the anchor to the cell under the cursor. Pressing right again lets you pick a new anchor.
4. Release the **left** button. The window fills the selected rectangle.

Press **Escape** at any point after the right click to cancel. The window stays where you dragged it, and no context menu appears.

Settings (menu-bar icon → Settings…): columns (1–24, default 6), rows (1–24, default 4), gap in points (0–64, default 0), and Start at login. Changes apply from the next gesture.

## Building

```sh
make app    # release build → build/Grigrid.app (ad-hoc signed)
make run    # make app, then open it
make test   # unit tests (grid math and coordinate conversion)
make clean
```

## Granting Accessibility

Grigrid needs Accessibility permission to watch mouse events and move windows. Pick **Grant Accessibility Access…** from the menu-bar icon, then turn Grigrid on under System Settings → Privacy & Security → Accessibility. The app checks every 2 s and starts the gesture once permission is granted. You don't need to relaunch it.

**Rebuilds and ad-hoc signing:** `make app` signs ad hoc by default, which gives each build a new code signature. macOS ties the permission to the signature, so after a rebuild the old entry can still show as on but no longer applies. If the menu shows "Grant Accessibility Access…" again, remove Grigrid from the list with **−** and add it again, or toggle it off and on, then relaunch.

If you have a local code-signing certificate, signing with it keeps the permission across rebuilds:

```sh
security find-identity -v -p codesigning     # list your identities
make app SIGN_ID="Apple Development: Your Name (XXXXXXXXXX)"
```

## Manual test checklist

- [ ] Plain title-bar drag still works, and right-click elsewhere still shows context menus.
- [ ] Left-drag a title bar, then right-click. The overlay appears on the correct screen, and the anchor follows the cursor while right is held.
- [ ] Release right: the rectangle grows from the anchor. Release left: the window fills it, including the gap.
- [ ] Escape cancels, and no stray context menu appears.
- [ ] Changing rows, columns, or gap applies to the next gesture, and the login item toggle works.
- [ ] Multi-monitor: the grid appears on the screen under the cursor, including on secondary displays placed above or left of the primary.

## License

[MIT](LICENSE)
