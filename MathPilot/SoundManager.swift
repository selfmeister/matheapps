import SwiftUI
import AVFoundation

class SoundManager: ObservableObject {
    private static var didConfigureAudioSessionCategory = false
    private static var didLogAudioSessionFailure = false
    private var audioPlayer: AVAudioPlayer?
    private var ambientPlayer: AVAudioPlayer?
    @Published var soundEnabled = true {
        didSet {
            if !soundEnabled {
                stopAllSounds()
            }
        }
    }

    init() {}

    func configure(soundEnabled: Bool) {
        self.soundEnabled = soundEnabled
    }

    func playExplosionSound() {
        guard soundEnabled else { return }
        playGeneratedSound(samples: makeExplosionSamples(), sampleRate: 22_050)
    }
    
    func playCorrectSound() {
        guard soundEnabled else { return }
        playGeneratedSound(samples: makeCorrectSamples(), sampleRate: 22_050)
    }
    
    func playWrongSound() {
        guard soundEnabled else { return }
        playGeneratedSound(samples: makeWrongSamples(), sampleRate: 22_050)
    }

    func playBossShotSound() {
        guard soundEnabled else { return }
        playGeneratedSound(samples: makeBossShotSamples(), sampleRate: 22_050)
    }

    func startAmbientSound(for vehicleType: VehicleType) {
        guard soundEnabled else { return }
        guard prepareAudioSessionForPlayback() else { return }

        let samples: [Int16]
        let sampleRate = 22_050

        switch vehicleType {
        case .jet:
            samples = makeJetAmbientSamples(sampleRate: sampleRate)
        case .tank, .unicorn:
            samples = makeTankAmbientSamples(sampleRate: sampleRate)
        }

        let data = makeWAVData(samples: samples, sampleRate: sampleRate)

        do {
            ambientPlayer = try AVAudioPlayer(data: data)
            ambientPlayer?.numberOfLoops = -1
            ambientPlayer?.volume = 0.22
            ambientPlayer?.prepareToPlay()
            ambientPlayer?.play()
        } catch {
            print("Could not play ambient sound: \(error)")
        }
    }

    func stopAmbientSound() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    func stopAllSounds() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopAmbientSound()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func playGeneratedSound(samples: [Int16], sampleRate: Int) {
        guard prepareAudioSessionForPlayback() else {
            print("SoundManager: Audio session not available")
            return
        }

        let data = makeWAVData(samples: samples, sampleRate: sampleRate)

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 0.95
            audioPlayer?.prepareToPlay()
            let didPlay = audioPlayer?.play() ?? false
            if !didPlay {
                print("SoundManager: Failed to start playback")
            }
        } catch {
            print("SoundManager: Could not play sound: \(error)")
        }
    }

    private func prepareAudioSessionForPlayback() -> Bool {
        let session = AVAudioSession.sharedInstance()

        do {
            if !Self.didConfigureAudioSessionCategory {
                // Use .playback category for game sounds - more reliable than .ambient
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                Self.didConfigureAudioSessionCategory = true
            }

            try session.setActive(true)
            return true
        } catch {
            logAudioSessionFailureIfNeeded(error)
            return false
        }
    }

    private func logAudioSessionFailureIfNeeded(_ error: Error) {
        guard !Self.didLogAudioSessionFailure else { return }
        Self.didLogAudioSessionFailure = true
        print("SoundManager: Audio session unavailable; continuing without sound. Error: \(error)")
    }

    deinit {
        ambientPlayer?.stop()

        if audioPlayer != nil || ambientPlayer != nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func makeCorrectSamples() -> [Int16] {
        let sampleRate = 22_050
        let duration = 0.22
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = exp(-time * 10.5)
            let sparkle = sin(2 * .pi * 880 * time)
            let harmony = sin(2 * .pi * 1320 * time) * 0.45
            let value = max(-1.0, min(1.0, (sparkle + harmony) * envelope))
            samples.append(Int16(value * Double(Int16.max) * 0.45))
        }

        return samples
    }

    private func makeWrongSamples() -> [Int16] {
        let sampleRate = 22_050
        let duration = 0.28
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = exp(-time * 7.0)
            let lowTone = sin(2 * .pi * 210 * time)
            let wobble = sin(2 * .pi * 160 * time) * 0.55
            let value = max(-1.0, min(1.0, (lowTone + wobble) * envelope))
            samples.append(Int16(value * Double(Int16.max) * 0.42))
        }

        return samples
    }

    private func makeBossShotSamples() -> [Int16] {
        let sampleRate = 22_050
        let duration = 0.24
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = exp(-time * 9.0)
            let zap = sin(2 * .pi * 380 * time)
            let sweep = sin(2 * .pi * (880 - (time * 1200)) * time) * 0.45
            let grit = Double.random(in: -0.25...0.25) * envelope
            let value = max(-1.0, min(1.0, ((zap + sweep) * envelope) + grit))
            samples.append(Int16(value * Double(Int16.max) * 0.58))
        }

        return samples
    }

    private func makeExplosionSamples() -> [Int16] {
        let sampleRate = 22_050
        let duration = 0.42
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        var filteredNoise = 0.0
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let noise = Double.random(in: -1...1)
            filteredNoise = (filteredNoise * 0.82) + (noise * 0.18)

            let envelope = exp(-time * 8.5)
            let rumble = sin(2 * .pi * 55 * time) * exp(-time * 6.0)
            let crack = filteredNoise * envelope
            let value = max(-1.0, min(1.0, (rumble * 0.55) + (crack * 0.9)))

            samples.append(Int16(value * Double(Int16.max) * 0.75))
        }

        return samples
    }

    private func makeJetAmbientSamples(sampleRate: Int) -> [Int16] {
        let duration = 1.6
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        var filteredNoise = 0.0
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let noise = Double.random(in: -1...1)
            filteredNoise = (filteredNoise * 0.94) + (noise * 0.06)
            let airyNoise = filteredNoise * 0.18
            let shimmer = sin(2 * .pi * 410 * time) * 0.015
            let value = max(-1.0, min(1.0, airyNoise + shimmer))
            samples.append(Int16(value * Double(Int16.max) * 0.55))
        }

        return samples
    }

    private func makeTankAmbientSamples(sampleRate: Int) -> [Int16] {
        let duration = 1.8
        let sampleCount = Int(Double(sampleRate) * duration)

        var samples: [Int16] = []
        samples.reserveCapacity(sampleCount)

        var filteredNoise = 0.0
        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let noise = Double.random(in: -1...1)
            filteredNoise = (filteredNoise * 0.9) + (noise * 0.1)
            let rumble = sin(2 * .pi * 48 * time) * 0.22
            let drone = sin(2 * .pi * 92 * time) * 0.08
            let engineTexture = filteredNoise * 0.08
            let value = max(-1.0, min(1.0, rumble + drone + engineTexture))
            samples.append(Int16(value * Double(Int16.max) * 0.5))
        }

        return samples
    }

    private func makeWAVData(samples: [Int16], sampleRate: Int) -> Data {
        let bitsPerSample = 16
        let channelCount = 1
        let byteRate = sampleRate * channelCount * bitsPerSample / 8
        let blockAlign = channelCount * bitsPerSample / 8
        let dataSize = samples.count * MemoryLayout<Int16>.size
        let chunkSize = 36 + dataSize

        var data = Data()

        data.append("RIFF".data(using: .ascii)!)
        data.append(UInt32(chunkSize).littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(UInt16(channelCount).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(bitsPerSample).littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(dataSize).littleEndianData)

        for sample in samples {
            data.append(sample.littleEndianData)
        }

        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        withUnsafeBytes(of: self.littleEndian) { Data($0) }
    }
}
