OpenCode Mobile — foreground-service demo video
==============================================

File:  fgs-demo.mp4   (720 × 1612, ~2 min, 445 KB)

WHAT IT SHOWS (recorded on a real phone, real server — nothing staged)
--------------------------------------------------------------------
0:00  The app is in the background; "Background notifications" is ON, so the
      foreground service is holding a live connection to the user's own
      OpenCode server (that is the dataSync foreground service).
0:12  An event arrives from the server while the app is NOT in the foreground:
      a run finished, and the app posts a notification about it.
0:53  The permanent notification underneath is the foreground service staying
      connected; tapping the event notification opens the app.

Nothing is uploaded and no data is transferred between devices — the service
only keeps this connection so the user is notified.

UPLOAD IT, THEN PASTE THE LINK
------------------------------
Play Console → App content → Foreground service permissions →
Data sync → Network processing → Other → Video link.

* YouTube: upload as **Unlisted** (a link-only video) — simplest and safest.
* Google Drive: works too, but the file must be shared as
  **"Anyone with the link → Viewer"**, and you must paste the *file* link.
  Verify it in an Incognito window: if it asks to sign in, it will be rejected.

Description to paste next to the link:

  The app keeps a live connection (server-sent events) to the OpenCode server
  that the user runs on their own computer, so it can notify them when the
  agent is waiting for a permission decision or has finished a run, while the
  app is in the background. The service holds that connection only; no data is
  uploaded or transferred between devices. The video shows the app in the
  background with the service running, an event notification arriving from the
  server, and the notification opening the app.

RE-RECORDING
------------
  adb shell screenrecord --bit-rate 6000000 --time-limit 170 /sdcard/fgs-demo.mp4
  # drive the phone, then:
  adb pull /sdcard/fgs-demo.mp4

Keep the video reachable — reviewers may re-check it on later updates.
