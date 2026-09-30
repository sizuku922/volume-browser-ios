# Volume Browser for iPhone

A minimal iOS browser that can amplify HTML5 audio/video using Web Audio.

- Opens normal websites in WKWebView.
- Provides a 100%–400% media gain slider.
- Not tied to ASMR.ONE.

## Limitations

This cannot change the iOS system output volume. It only amplifies media that the webpage exposes as routable HTML5 audio/video. Protected playback, some cross-origin/proprietary players, or media that cannot be routed through Web Audio may not be boostable.

The project is built unsigned by GitHub Actions. The resulting IPA is intended to be signed for the user's device with AltStore/AltServer.
