# Native iOS Teleprompter — Build Brief

Handoff spec for building a **native iOS** version of a teleprompter app. A working
web/PWA version already exists (see **Reference**); the user is moving to native for
reliability and audio quality. A new chat should read this top-to-bottom, confirm the
plan, then build.

## Goal
A native iOS teleprompter for the user's **own iPhone** (NOT the App Store) that records
video while scrolling a script positioned right next to the camera lens. The scrolling
text is a read-only overlay and must **never** be baked into the recorded video.

## Why native (what the web version couldn't do reliably)
- **Reliable long recordings.** iOS Safari's `MediaRecorder` hit a resource ceiling on
  ~3-minute clips — depending on settings it dropped either the audio or the video track
  partway through. We worked around it (2s flush + lowered bitrate) and it *works*, but the
  user (reasonably) doesn't trust it. AVFoundation records long clips reliably.
- **Cleaner audio.** `getUserMedia` applies voice-call DSP (echo cancellation, noise
  suppression, auto-gain) to the mic by default, which muddies a good external mic.
  AVFoundation can capture the mic clean — this is the specific complaint that pushed the
  move to native.
- **Camera-roll quality + direct save.** Native writes a full-quality `.mov` straight to
  Photos; the web version saved via the share sheet at a capped bitrate.
- **More of Apple's camera pipeline** than a browser stream gets.

## The user & setup (build for THIS specifically)
- **Device:** iPhone SE (2nd gen). **Front camera maxes at 1080p30** (no 4K on the front) —
  target 1080p30.
- **Orientations:** primarily **landscape, camera on the LEFT**; sometimes **portrait,
  camera at the TOP**. The script must sit next to wherever the lens physically is.
- **Tripod-mounted** — no stabilization needed; workflow is tap record → read → tap stop, so
  a countdown before recording is helpful.
- **Audio:** external **wireless mic via the Lightning port** (receiver plugged in). Capture
  it cleanly, no aggressive DSP. They use it with the native Camera app all the time.
- **Lighting:** light panel to their left, reflector to their right (good, even light).
- **Distribution:** their phone only. **Free personal Apple ID signing** (no $99 Developer
  Program); such apps expire after **7 days** and are refreshed by re-running from Xcode.
- **Toolchain:** on a Mac (macOS 15.7) but currently has **only Command Line Tools —
  full Xcode must be installed** (App Store, large download) before building/running on device.
  Apple ID is presumably osmithy@gmail.com.

## Features to match (from the web version)
1. **Script editor:** paste/type a script; persists between launches.
2. **Fullscreen front-camera preview** at 1080p30.
3. **Scrolling script overlay next to the lens** — overlay ONLY, never in the recording:
   - **Landscape, camera-left →** text **column on the LEFT**, reading line at vertical center.
   - **Portrait, camera-top →** text **band near the TOP**, reading line high near the lens.
   - Position options: **Top / Left / Center / Right**.
4. **Settings (persisted):** scroll speed, font size, text width (column vs band widths
   differ), text dimming, text position, mirror preview on/off, countdown (Off/3s/5s).
5. **Reading-line indicator** at the focus point; smooth scrolling.
6. **Controls:** Record (countdown → then scroll + record start together), Play/Pause scroll,
   Restart-to-top, back to the script editor. In the portrait/top layout the web version put
   the status bar + controls at the **bottom** so nothing sits between the script and the lens —
   replicate that idea.
7. **Mirror the preview** for comfort, but **record un-mirrored** (how others see them).
8. **Save to Photos** after each take, with a review → re-record / discard / save step.
9. **Keep the screen awake** while recording/reading (`UIApplication.shared.isIdleTimerDisabled`).

## Defaults to carry over (from the web version)
- speed 65 (px/s — translate to pts/sec), font ~38pt, landscape column width ~46% of the
  short side, portrait band width ~92%, dimming ~35%, countdown 3s, mirror ON, 1080p30.
- Landscape columns: reading line at ~50% height. Portrait top band: box starts ~4% from the
  top, ~46% tall, reading line ~28% down the band (near the lens, clear of the status bar).

## Suggested native approach
- **SwiftUI** + **AVFoundation** (`AVCaptureSession`, front `AVCaptureDevice` at
  `.hd1920x1080`/30fps; `AVCaptureMovieFileOutput` for a clean `.mov`, or `AVAssetWriter` for
  more control).
- **Audio:** add the connected mic as an `AVCaptureDeviceInput`; configure `AVAudioSession`
  (category `.playAndRecord`, mode `.videoRecording`, avoid voice-processing) so the Lightning
  mic is captured cleanly.
- **Preview + overlay:** `AVCaptureVideoPreviewLayer` wrapped for SwiftUI, with SwiftUI text
  views on top (display-only).
- **Scrolling:** `CADisplayLink` / `TimelineView` driving a vertical offset; smooth at 60fps.
- **Save:** `PHPhotoLibrary` (add-only). `Info.plist` needs `NSCameraUsageDescription`,
  `NSMicrophoneUsageDescription`, `NSPhotoLibraryAddUsageDescription`.
- **Orientation:** support landscape + portrait; place the text box next to the lens per
  orientation.
- **Testing caveat:** the **iOS Simulator has no camera** — all camera/audio/recording work
  must be tested on the **physical iPhone SE 2** via Xcode. The Simulator is only useful for
  laying out non-camera UI.

## Reference (the working web version)
- Live: https://osmithy.github.io/teleprompter-app/
- Code: this repo — `index.html` is the entire app; read it for the exact layout, box
  geometry, defaults, and UX flow. GitHub: `osmithy/teleprompter-app`.
- Project memory (auto-loads in this folder) has the full history and rationale.

## First steps for the new chat
1. Confirm scope with the user.
2. Help install/verify **full Xcode** and set up **free personal signing** with their Apple ID.
3. Scaffold the SwiftUI + AVFoundation project (a subfolder like `native/` here, or a new folder).
4. Get **camera preview + record-to-Photos** working first (the core reliability win), then
   layer on the scrolling overlay and settings.
5. Deploy to the real iPhone SE 2 to test camera + the Lightning mic (Simulator can't).
