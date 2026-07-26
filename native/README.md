# Native iOS Teleprompter

Native **SwiftUI + AVFoundation** rebuild of the web teleprompter, for osmithy's own
**iPhone SE (2nd gen)**. Not for the App Store — signed with a **free personal Apple ID**
and run from Xcode. See `../NATIVE_APP_BRIEF.md` for the full rationale.

## Build machine reality
- 2014 Intel MacBook Pro (`MacBookPro11,3`), macOS Sequoia **15.7.4** via OpenCore Legacy Patcher.
- The last Intel-compatible Xcode line is **Xcode 26**. The newest that runs on macOS 15.7 is
  **Xcode 26.3** (26.4+ requires macOS 26 "Tahoe"). Xcode 27 will be Apple-Silicon-only.
- **Test on the physical iPhone only** — the Simulator has no camera, and the Simulator /
  live SwiftUI Previews can be flaky under OCLP on this GPU. We build straight to the device.

## 1. Install Xcode 26.3
A free Apple ID is enough — you do **not** need the $99 Developer Program to download Xcode
or to sign apps for your own device.
1. https://developer.apple.com/download/all/ → sign in (osmithy@gmail.com).
2. Search **"Xcode 26.3"** → download the **.xip**. If offered "Apple silicon" vs
   "Universal", choose **Universal** (it contains the Intel slice — required on this Mac). ~15 GB.
3. Double-click the `.xip` to expand it (slow on this Mac: ~20–40 min) → produces `Xcode.app`.
4. Move `Xcode.app` into `/Applications`, open it once, approve "install additional components".
5. Point the command-line tools at it:
   ```
   sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch
   xcodebuild -version    # expect: Xcode 26.3
   ```
> The Mac App Store may only offer the newest Xcode (which needs macOS 26) — use the `.xip` above.

## 2. Create the project
Xcode → File → New → Project → **iOS → App**:
- Product Name: **Teleprompter**
- Interface: **SwiftUI**, Language: **Swift**, Storage: **None**, tests off
- Organization Identifier: **com.osmithy** → bundle id `com.osmithy.Teleprompter`
- Save into this **`native/`** folder.

Xcode 26 uses file-system-synchronized groups, so `.swift` files placed in the generated
`Teleprompter/` folder are compiled automatically (no manual "Add to project" step).

## 3. Free personal signing
- Xcode → Settings → Accounts → **+** → Apple ID → sign in.
- Target → **Signing & Capabilities** → Team = "*(Your Name)* (Personal Team)",
  **Automatically manage signing** ON. Bundle id `com.osmithy.Teleprompter` is unique enough.

## 4. Required Info.plist usage strings
- `NSCameraUsageDescription` — "Records video of you while you read your script."
- `NSMicrophoneUsageDescription` — "Records your voice through the built-in or external mic."
- `NSPhotoLibraryAddUsageDescription` — "Saves your finished takes to your Photos library."

## 5. Run on the iPhone SE 2
- Connect via USB → **Trust This Computer** on the phone.
- iPhone → Settings → Privacy & Security → **Developer Mode** → ON (the phone reboots).
- First launch: iPhone → Settings → General → VPN & Device Management → trust the dev cert.
- Free-signed apps **expire after 7 days** — just re-run from Xcode to refresh.

## Roadmap
1. **Camera core** — front camera preview + record 1080p30 + clean external-mic audio +
   save to Photos.  ← the reliability win; build & verify on device first.
2. **Scrolling overlay** — script scrolls in a box next to the lens, overlay only
   (never in the recording) + reading-line + countdown.
3. **Layouts** — landscape camera-left (left column) / portrait camera-top (top band);
   position options Top / Left / Center / Right; controls kept clear of the text.
4. **Settings (persisted)** — speed, font, width (column vs band), dimming, position,
   mirror, countdown.
5. **Review & polish** — save / re-record / discard; keep the screen awake while reading.

## Defaults (carried from the web version)
speed **65 pt/s**, font **38**, landscape column **46%** of the short side, portrait band
**92%**, dimming **35%**, countdown **3s**, mirror **ON** (but record **un-mirrored**), **1080p30**.
Landscape: reading line at ~50% height. Portrait top band: box starts ~4% from top, ~46%
tall, reading line ~28% down (near the lens, clear of the status bar).
