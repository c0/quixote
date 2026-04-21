# Development Notes

## Full-Rect Hit Targets in SwiftUI

SwiftUI controls can render as if they fill a custom visual region while their
effective click target remains limited to the intrinsic label content. We hit
this with the run button caret menu and the stats summary rail: the painted
right side or nav cell looked clickable, but only the icon/text area responded.

For fixed custom controls where the entire painted rectangle must respond, use
a transparent AppKit-backed hit target with `NSViewRepresentable`:

- Render the SwiftUI visual content normally.
- Overlay or layer a borderless transparent `NSButton` that fills the intended
  hit rectangle.
- Route the button action through a coordinator back into SwiftUI state.
- For menu affordances, pop an `NSMenu` from the hosted `NSButton` instead of
  relying on SwiftUI `Menu` label hit testing.

Use this pattern sparingly. Prefer plain SwiftUI first, but use the AppKit
bridge when `.frame(...)`, `.contentShape(Rectangle())`, transparent fills, or
`ButtonStyle(.plain)` still leave dead zones in a custom macOS control.

Current examples:

- `Quixote/Views/RunControlsView.swift`: `RowLimitMenuHitTarget`
- `Quixote/Views/StatsPanelView.swift`: `StatsSummaryHitTarget`
