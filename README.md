# Open Scripture Voice — Architecture B (On-Device TTS)

Free, open-source, offline-first Bible listening app for Android. The Bible
text (WEB, public domain) ships in the app; audio is **synthesized on the
device at listen time** — not pre-rendered and bundled. No backend, no
accounts, no analytics, no network required for any core function.

## Status

This repo is the Phase 1–4 codebase per the build spec:

- ✅ Project structure, SQLite schema, models, repositories (§8, §13)
- ✅ `TtsEngine` abstraction + sherpa-onnx implementation for Piper and
  Kokoro packs (§4–6)
- ✅ Cache-first runtime synthesis pipeline: verse-by-verse synthesis on a
  cache miss, verses streamed into the player queue as they land, WAV cache
  with a size cap and oldest-first eviction, "make available offline"
  pre-warm (§7)
- ✅ Preprocessing pipeline: validation → punctuation/whitespace
  normalization → number expansion → biblical-name lexicon, with
  `pipeline_version` caching of normalized text (§10) — **unit-tested**
- ✅ Player: just_audio + audio_service, gapless verse queue, background /
  lock-screen controls, pitch-corrected speed (never re-synthesizes),
  sleep timer (§7, §11)
- ✅ UI: Library, Listening (with "synthesizing…" indicator), Voice &
  Language Pack Manager, Settings with Cache Manager (§11)
- ✅ Seed data: all 66 books' metadata + Genesis 1, Psalm 23, John 3
  (Phase 1 passages); `tools/build_seed.py` converts the full WEB text

Not yet done (needs hardware / accounts we don't have here):

- ⏳ The bundled Piper voice itself — drop the pack into
  `assets/voices/piper-en-default/` (see the README there). Not committed
  because it's ~60 MB of binaries and its license must be confirmed first.
- ⏳ On-device acceptance testing (Phases 1, 2, 6) — needs real 2/4/6 GB
  Android devices.
- ⏳ Full WEB text seed (Phase 5) — run `tools/build_seed.py` on the WEB
  public-domain release.
- ⏳ Voice pack sideload picker UI polish (Phase 7).

## Build & run

```bash
flutter pub get
# add the default Piper voice pack to assets/voices/piper-en-default/
flutter run            # on a connected Android device
flutter test           # preprocessing unit tests (pure Dart, no device)
```

Android config: create the platform scaffold with `flutter create .`
(org of your choice), then set `minSdkVersion 23`+ and add to
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback" android:exported="true">
  <intent-filter>
    <action android:name="android.media.browse.MediaBrowserService" />
  </intent-filter>
</service>
```

## Architecture at a glance

```
Library → chapter → tts_cache lookup (book, chapter, voice)
   HIT  → enqueue cached verse WAVs → play instantly
   MISS → "synthesizing…" → per verse: normalize → lexicon → synthesize
          → stream into just_audio queue (playback starts at verse 1)
          → write WAV to cache → mark chapter cached → evict if over cap
```

Speed changes are `just_audio` playback-rate only — one cached file serves
every speed. `TtsEngine` is an interface, so Kokoro/Pocket-TTS packs slot in
without touching the pipeline.

## Licensing checklist — verify current terms before shipping (§9)

- [ ] WEB text: public domain ✅
- [ ] Piper: `rhasspy/piper` (MIT) is archived; active line is
      `OHF-Voice/piper1-gpl` (**GPL-3.0**, embeds espeak-ng) — reciprocal
      source-sharing obligations on distribution
- [ ] Kokoro-82M: Apache-2.0 weights, but `misaki` G2P can fall back to
      espeak-ng (GPL-3.0) — **unresolved upstream** (hexgrad/kokoro#247);
      get it checked or engineer around the fallback
- [ ] Pocket-TTS: license not established — confirm before bundling
- [ ] sherpa-onnx: permissive — confirm current in-repo terms
- [ ] Each voice model may carry its own license — check per voice
- [ ] Plan: license the app (at minimum the TTS/audio module)
      GPL-3.0-compatible

## Roadmap (per spec §14)

Phase 1 synthesis proof → 2 engine bake-off → 3 preprocessing (done, needs
on-engine listening QA) → 4 offline MVP shell (done, needs device pass) →
5 full Bible text QA → 6 low-end hardware pass → 7 pack manager +
sideload distribution.
