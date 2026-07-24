# Teleprompter

A free, no-frills teleprompter web app that runs in your phone's browser. Scrolls
your script in a column right next to the camera lens while you record video — so
your eyes stay on-camera. The text is only ever an on-screen overlay; it is **never**
baked into the recording.

Built for an iPhone SE (2nd gen) held in **landscape with the camera on the left**,
but the text column can be moved (left / center / right) for any setup.

## Using it

1. Open the site on your phone and tap **Start camera** (allow camera + microphone).
2. Rotate to landscape with the camera on the left.
3. Paste your script, tap the red **record** button — a countdown runs, then it records
   and scrolls together.
4. Tap **stop**, then **Save to Photos**.

Tap the video area (or the play button) to pause/resume the scroll; drag it to scrub.

## Settings

Scroll speed · font size · column width · text dimming · text position · mirror
preview · countdown length. Everything is remembered between sessions.

## Notes on quality

The app requests the front camera's full **1080p @ 30fps** and records at ~10 Mbps
(the resolution readout at the top shows what you're actually getting). This matches
the SE 2's front-camera ceiling. In good, even light it looks great; in dim or harsh
light Apple's native Camera app will still look a bit cleaner, since browsers get less
of Apple's image processing.

## Install to your home screen

In Safari: **Share ▸ Add to Home Screen**. It then opens fullscreen with its own icon,
like a normal app.

## Tech

A single self-contained `index.html` (no build step, no dependencies) plus a PWA
manifest and icons. Camera via `getUserMedia`, recording via `MediaRecorder`, kept awake
with the Wake Lock API, saved through the Web Share sheet.
