# Bundled default voice (placeholder)

Place the default Piper voice pack here before building:

- `<voice>.onnx` and `<voice>.onnx.json` — the Piper/VITS model
- `tokens.txt`
- `espeak-ng-data/` — phonemizer data

Expected total: ~60–65 MB, so the base APK works fully offline from first
launch on a 4GB phone. Heavier engines (Kokoro, Pocket-TTS) are downloaded
or sideloaded as packs, never bundled.

IMPORTANT — licensing (see §9 of the build spec): current Piper voices are
built on `OHF-Voice/piper1-gpl` (GPL-3.0, embeds espeak-ng). Confirm the
license of the exact voice model you bundle, and plan for the app's
TTS/audio module to be GPL-3.0-compatible.
