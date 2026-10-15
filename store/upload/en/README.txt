OpenCode Mobile — English store assets (ready to upload)
========================================================

Drop these into Google Play Console → your app → Store listing (default
language: English), in this order:

  1-app-icon-512x512.png         → App icon            (512 × 512, no alpha)
  2-feature-graphic-1024x500.png → Feature graphic      (1024 × 500)
  3-phone-home.png               → Phone screenshots    (1080 × 2160)
  4-phone-live-chat.png          → Phone screenshots
  5-phone-pairing.png            → Phone screenshots

Notes
-----
* Phone screenshots: 2 minimum, 8 maximum. All three are 1080 × 2160 (2:1),
  which Play accepts. Order matters — the first one is shown in search.
* These are the ENGLISH assets. For the Arabic listing add the language in
  Play Console, then upload store/screenshots/ar/ (4 screenshots).
* The app icon and feature graphic are language-independent; the same files
  work for every listing language.

Regenerating
------------
  python3 tools/generate_brand_assets.py            # icon + feature graphic
  bash tools/capture_store_screenshots.sh           # screenshots from a phone
  python3 tools/storeify_screenshots.py <shots> --out store/screenshots/en

Source of truth: the repository (store/, tools/) — never edit these copies.
