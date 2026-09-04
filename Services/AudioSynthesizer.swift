import AVFoundation

private struct SynthParameters {
    var masterVolume: Double = 0.5
    var oscillatorCount: Int = 3          // 1...5, driven by Energy
    var reverbWetDry: Float = 35          // kept mostly dry — see notes below
    var rootFrequency: Double = 110.0     // A2, shifted by Hue Offset
    var minorMix: Double = 0.5            // 0 = major, 1 = minor, driven by Saturation
    var lowShelfGain: Float = 0           // dB, driven by Brightness (dark = boost lows)
    var highShelfGain: Float = 0          // dB, driven by Brightness (bright = boost highs)
    var arpeggioSpeed: Double = 0.06      // Hz-ish, how fast voices swell in/out
    var arpeggioDirection: ArpeggioDirection = .up
}

enum ArpeggioDirection {
    case up, down, upDown
}

/// Generates the ambient pad in real time via a small sine-oscillator bank, routed
/// through a 2-band shelving EQ (register/brightness) and reverb (energy) before
/// hitting the mixer.
///
/// v2 tuning notes (fixes the "can barely hear it" issue):
/// - Brightness used to drive a *highpass* filter with a cutoff up to ~2.1kHz. The
///   pad's fundamentals live around 110–260Hz, so at ordinary brightness settings the
///   highpass sat entirely above the signal and muted almost everything. Replaced with
///   a low-shelf/high-shelf pair that tilts tone warmer/brighter without ever being
///   able to remove the fundamental.
/// - Reverb could reach 100% wet at low Energy, which reads as a faint wash rather
///   than a clear tone. Range is now narrower (20–45%) and always majority-dry.
/// - Overall gain headroom increased, and the Volume slider now uses a perceptual
///   curve (pow 0.6) so the middle of the slider sounds like a comfortable middle,
///   not a barely-audible sliver.
/// - Arpeggio swell sped tied to Energy, but the whole range slowed down so it stays
///   calm even at 100%.
final class AudioSynthesizer {
    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private let mixer = AVAudioMixerNode()

    private var params = SynthParameters()
    private let paramsLock = NSLock()

    private var sourceNode: AVAudioSourceNode!
    private var phases = [Double](repeating: 0, count: 5)
    private var elapsedSamples: Double = 0

    // Interval sets (semitones from root) used to build an ambient add9-style pad chord.
    private let majorIntervals: [Double] = [0, 4, 7, 11, 14]  // maj7(9)
    private let minorIntervals: [Double] = [0, 3, 7, 10, 14]  // min7(9)

    init() {
        buildEngine()
    }

    private func buildEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Constants.audioSampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            self.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
            return noErr
        }

        engine.attach(sourceNode)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(mixer)

        reverb.loadFactoryPreset(.mediumHall) // smaller/less diffuse than largeHall
        reverb.wetDryMix = params.reverbWetDry

        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 200
        eq.bands[0].gain = params.lowShelfGain
        eq.bands[0].bypass = false

        eq.bands[1].filterType = .highShelf
        eq.bands[1].frequency = 2000
        eq.bands[1].gain = params.highShelfGain
        eq.bands[1].bypass = false

        engine.connect(sourceNode, to: eq, format: format)
        engine.connect(eq, to: reverb, format: format)
        engine.connect(reverb, to: mixer, format: format)
        engine.connect(mixer, to: engine.mainMixerNode, format: format)

        mixer.outputVolume = Float(pow(params.masterVolume, 0.6))
    }

    func start() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("AudioSynthesizer: failed to start engine — \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    /// Called whenever sliders or weather change.
    func update(preferences: UserPreferences, weather: WeatherData?) {
        var newParams = SynthParameters()

        // Perceptual volume curve — makes the slider's midpoint sound like "half", not
        // a barely-audible sliver (linear gain maps poorly onto perceived loudness).
        newParams.masterVolume = pow(preferences.volume.clamped(to: 0...1), 0.6)

        newParams.oscillatorCount = 1 + Int(preferences.energy.clamped(to: 0...1) * 4) // 1...5

        // Always majority-dry so the pad stays clearly audible; reverb now only adds
        // ambience rather than being able to wash the signal out entirely.
        newParams.reverbWetDry = Float(45 - preferences.energy.clamped(to: 0...1) * 25) // 45 (calm) ... 20 (energetic)

        let semitoneShift = preferences.hueOffset / 180.0 * 12.0 // ±12 semitones
        newParams.rootFrequency = 110.0 * pow(2.0, semitoneShift / 12.0)

        newParams.minorMix = 1.0 - preferences.saturation.clamped(to: 0...1)

        let brightness = preferences.brightness.clamped(to: 0...1)
        newParams.lowShelfGain = Float((0.5 - brightness) * 10)   // dark  -> up to +5dB low boost
        newParams.highShelfGain = Float((brightness - 0.5) * 10)  // bright -> up to +5dB high boost

        switch preferences.flowDirection {
        case .cw: newParams.arpeggioDirection = .up
        case .ccw: newParams.arpeggioDirection = .down
        case .oscillate: newParams.arpeggioDirection = .upDown
        }
        // Slowed down considerably — stays gentle even at 100% Energy.
        newParams.arpeggioSpeed = 0.03 + preferences.energy.clamped(to: 0...1) * 0.09 // 0.03–0.12 Hz

        paramsLock.lock()
        params = newParams
        paramsLock.unlock()

        mixer.outputVolume = Float(newParams.masterVolume)
        eq.bands[0].gain = newParams.lowShelfGain
        eq.bands[1].gain = newParams.highShelfGain
        reverb.wetDryMix = newParams.reverbWetDry
    }

    // MARK: Real-time render

    private func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        paramsLock.lock()
        let p = params
        paramsLock.unlock()

        let intervals = zip(majorIntervals, minorIntervals).map { major, minor in
            major + (minor - major) * p.minorMix
        }

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let sampleRate = Constants.audioSampleRate
        let voiceCount = max(1, min(p.oscillatorCount, intervals.count))
        // More headroom than v1 (was 0.3 total) — that ceiling, stacked with the old
        // EQ/reverb issues above, made the pad very hard to hear.
        let voiceGain = 1.0 / Double(voiceCount) * 0.55

        for frame in 0..<frameCount {
            let time = elapsedSamples / sampleRate
            var sample: Double = 0

            for voice in 0..<voiceCount {
                let frequency = p.rootFrequency * pow(2.0, intervals[voice] / 12.0)
                phases[voice] += 2.0 * Double.pi * frequency / sampleRate
                if phases[voice] > 2.0 * Double.pi { phases[voice] -= 2.0 * Double.pi }

                let stagger = Double(voice) / Double(voiceCount)
                let sweepPhase: Double
                switch p.arpeggioDirection {
                case .up:     sweepPhase = time * p.arpeggioSpeed - stagger
                case .down:   sweepPhase = -time * p.arpeggioSpeed - stagger
                case .upDown: sweepPhase = time * p.arpeggioSpeed * sin(stagger * .pi)
                }
                let sweep = 0.45 + 0.55 * (0.5 + 0.5 * sin(2 * .pi * sweepPhase))

                sample += sin(phases[voice]) * voiceGain * sweep
            }

            for buffer in ablPointer {
                let bufferPointer = buffer.mData!.assumingMemoryBound(to: Float.self)
                bufferPointer[frame] = Float(sample)
            }

            elapsedSamples += 1
        }
    }
}
