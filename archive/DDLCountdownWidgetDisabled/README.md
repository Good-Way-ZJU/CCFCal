# DDLCountdownWidget

This folder contains the first-pass macOS WidgetKit implementation for DDLCal.

Current status:
- Reads a multi-item countdown snapshot JSON.
- Supports small / medium / large layouts.
- Medium and large layouts show multiple upcoming deadlines.
- Uses bundled sample data for previews / early wiring.

How to hook it up in Xcode now:
1. Open `CCFCal.xcodeproj`.
2. File -> New -> Target -> Widget Extension -> macOS.
3. Name it `DDLCountdownWidgetExtension`.
4. Add these files into the new widget target:
   - `DDLCountdownModels.swift`
   - `DDLCountdownWidget.swift`
   - `DDLCountdownWidgetBundle.swift`
   - `SampleCountdownSnapshot.json`
5. In Signing & Capabilities, add the App Group:
   - `group.com.guwei.ddlcal.shared`
6. Add the same App Group to the main `CCFCal` app target.
7. Keep the widget minimum macOS version at 14.0 or newer.
8. Build once, then subscribe to a few venues in the main app.
9. Add the widget from the desktop widget gallery and pick `DDL Countdown`.

Current integration status:
- The main app now writes countdown snapshots to the shared App Group container when available.
- The widget loader already reads from `group.com.guwei.ddlcal.shared`.
- Medium and large widget layouts show multiple upcoming deadlines.
