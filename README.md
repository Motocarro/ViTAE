# ViTAE — Vivid Temporal Ambient Engine

A lightweight macOS app that generates real-time ambient soundscapes from the time of
day and the weather outside your window, paired with a slow, flowing color background
that reflects the same data. Six sliders, no presets, nothing to configure before it
sounds right — the goal is something you put on and forget about, not another app to
tune.

## What it does

ViTAE reads two inputs continuously: **what time it is**, and **what the weather's
doing where you are**. Those feed two outputs at once:

- **A generative audio pad** — a small bank of sine-wave oscillators, tuned to an
  ambient chord and gently shaped by reverb and EQ, playing continuously through your
  Mac's speakers.
- **A flowing color background** — a soft, slowly-shifting gradient that leans warm at
  sunrise, warm through the day, a warm/cool mix at dusk, and cold blue-indigo at
  night.

Six sliders let you bend both without ever needing a preset: **Volume**, **Energy**
(how lively the pad and the color drift are), **Hue Offset** (nudge the palette warmer
or cooler), **Saturation**, **Brightness**, and **Flow Direction** (Forward / Reverse /
Sway). Every slider starts neutral on first launch — there's no "default preset" to
undo, and the app never assumes a mood for you.

Everything runs locally. Weather is fetched from OpenWeatherMap once a day (or on
manual sync) and cached on disk; if you're offline, ViTAE falls back to the cache
silently rather than failing loudly. Location can come from GPS or a manual city
search. No audio, location, or usage data ever leaves the device except the weather
API request itself.

## How it works

**Time + weather → color.** `ColorCalculator` maps the current hour to a hue using a
set of anchor points across a 24-hour cycle (midnight is cold indigo, sunrise is warm
orange, midday is warm gold, dusk is magenta — a deliberate warm/cool blend — evening
cools back down), interpolated smoothly rather than jumping between fixed buckets.
Weather conditions (sunny/cloudy/rainy/stormy) separately scale saturation and
brightness. `ColorFlowState` then adds a slow, bounded sway around that base hue —
driven by the Energy slider — and `ColorFlowOrbView` renders the result as a full-bleed
radial gradient on a `SwiftUI Canvas`, redrawn via `TimelineView` at a fixed frame rate.

**Time + weather → sound.** `AudioSynthesizer` drives a handful of sine oscillators
directly through `AVAudioSourceNode`, tuned to a chord that blends between major and
minor voicings (controlled by Saturation), routed through a two-band shelving EQ
(Brightness tilts warm/cool tone) and a reverb (Energy controls how dry vs. spacious it
sounds) before hitting the output. Oscillator count, root pitch, and swell speed are
all driven by the sliders in real time; parameter changes are applied via a lock
around a small snapshot struct so they're safe to read from the real-time audio thread.

**Location + weather pipeline.** `LocationService` wraps CoreLocation for GPS and
`CLGeocoder` for manual city search. `WeatherService` fetches from OpenWeatherMap,
caches the result to `Application Support`, and serves that cache automatically if a
fresh fetch fails — the UI just shows a small offline indicator rather than an error.

**State.** `AppState` is the single source of truth: it owns the persisted
`UserPreferences` (the six sliders + any location override), the live `WeatherData`,
and instances of every service, and it's the only thing views observe.

## Tech stack

- Swift, SwiftUI (Canvas + TimelineView for rendering)
- AVAudioEngine / AVAudioSourceNode for the generative audio
- CoreLocation for GPS + geocoding
- URLSession + OpenWeatherMap (free tier) for weather, with local JSON caching
- UserDefaults for slider/preference persistence
- macOS 13+, no third-party dependencies

## Project structure

```
ViTAE/
├── App/        — app entry point + root view
├── Views/      — background, settings panel, top bar, clock, location search
├── Models/     — app state, persisted preferences, weather data, color-flow math
├── Services/   — weather, location, audio synthesis, color calculation, persistence
├── Utils/      — shared constants and small extensions
└── Resources/  — entitlements
```

## Known issues

- **Xcode project file is hand-authored.** It wasn't exported from a real Xcode
  install, so while it's been checked for internal consistency (every file reference
  verified against disk, balanced structure, unique object IDs), it hasn't been
  confirmed against an actual Xcode build. Flag anything that looks like a project-file
  problem (as opposed to an ordinary Swift error) rather than assuming it's your setup.
- **Audio gain staging was recently reworked** (EQ, reverb range, master gain curve)
  and hasn't had extended real-world listening across a wide range of speakers/headphones.
  It may still need tuning.
- **Real-time parameter access uses a plain `NSLock`**, not a lock-free structure. Fine
  in practice for occasional slider changes, but not textbook-correct real-time-audio
  safety — worth revisiting if audio glitches ever show up under load.
- **No automated tests** yet (unit or UI).
- **Placeholder bundle identifier** (`com.example.ViTAE`) — needs to be changed to your
  own reverse-DNS before any real distribution or notarization.
- **No custom app icon** — currently uses Xcode's default icon.
- **Weather resolution is coarser than "daily."** The free OpenWeatherMap endpoint in
  use returns 3-hour steps, not true calendar-day forecasts; "today's" weather is
  approximated from the nearest entry.
- **Silent failure on a bad/missing API key.** If `Constants.weatherAPIKey` is wrong,
  ViTAE just falls back to generic weather rather than surfacing an error — fine for
  the ambient-first philosophy, but not obvious if you're debugging.

## Roadmap / future updates

**Near-term**
- Custom app icon and general visual polish pass
- Sleep timer / auto-stop
- Menu bar mini-player mode
- Accessibility pass — VoiceOver labels, Reduce Motion support for the flowing background
- Swap `AudioSynthesizer`'s parameter locking for a lock-free double buffer

**Mid-term**
- Optional, opt-in "save this combination" for slider states — without turning it into
  a preset picker on first launch; the zero-presets-by-default philosophy stays
- Richer weather-reactive visuals (e.g. a subtle particle effect for rain/storms)
- Upgrade to OpenWeatherMap's One Call API for true daily forecasts
- iCloud sync of preferences across Macs
- Automated tests for the color/audio math (`ColorCalculator`, `ColorFlowState`) and
  basic UI tests for the settings panel

**Further out / ideas**
- iOS/iPadOS companion
- Extending support to an eventual HomePod with a screen (HomePad), Amazon Echo Show, Google Nest Hub
- Shortcuts / App Intents support (e.g. "Start ViTAE")
- Additional chord/scale options for the generative pad
- Localization

## Privacy

Everything runs locally except the weather API call itself, which sends only
latitude/longitude to OpenWeatherMap. No analytics, telemetry, or account system.
Location, weather cache, and preferences never leave the device.

## License

This project is protected by the GNU General Public License 3.0.

## Thanks

A special thank goes to Claude. I don't think I have to explain why.
