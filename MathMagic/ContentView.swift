import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @StateObject private var gameManager = GameManager()
    @StateObject private var soundManager = SoundManager()
    @StateObject private var appSettings = AppSettings()
    @State private var showingAnalytics = false
    @State private var showingSettings = false
    @State private var showingMissions = false
    @State private var showingResetStatisticsConfirmation = false
    
    var body: some View {
        GeometryReader { geometry in
            let copy = AppCopy(language: appSettings.language)
            let accessibilityOptions = effectiveAccessibilityOptions
            let reservedTopArea = geometry.safeAreaInsets.top + 18
            let vehicleBottomInset: CGFloat = gameManager.vehicleType == .unicorn ? 126 : 76
            let aircraftPosition = CGPoint(
                x: geometry.size.width / 2,
                y: max(160, geometry.size.height - vehicleBottomInset)
            )

            ZStack {
                ThemeFillView(vehicleType: gameManager.vehicleType)
                    .ignoresSafeArea()

                BackgroundView(
                    vehicleType: gameManager.vehicleType,
                    size: geometry.size
                )
                
                // Game area
                ZStack {
                    ForEach(gameManager.projectiles) { projectile in
                        ProjectileView(
                            projectile: projectile,
                            vehicleType: gameManager.vehicleType,
                            accessibilityOptions: accessibilityOptions
                        )
                    }

                    ForEach(gameManager.flyingNumbers) { number in
                        FlyingNumberView(
                            number: number,
                            vehicleType: gameManager.vehicleType,
                            accessibilityOptions: accessibilityOptions
                        ) {
                            gameManager.tappedNumber(number)
                            if !number.isCorrect {
                                soundManager.playWrongSound()
                            }
                        }
                    }

                    ForEach(gameManager.explosions) { explosion in
                        ExplosionView(
                            explosion: explosion,
                            accessibilityOptions: accessibilityOptions
                        )
                    }

                    if let boss = gameManager.bossEntity {
                        BossView(
                            boss: boss,
                            state: gameManager.bossFightState,
                            vehicleType: gameManager.vehicleType,
                            accessibilityOptions: accessibilityOptions
                        )
                        .allowsHitTesting(false)
                        .zIndex(8)
                    }

                    VehicleView(vehicleType: gameManager.vehicleType)
                        .position(aircraftPosition)
                }

                VStack {
                    if gameManager.gameStarted {
                        TopGameHUD(
                            topInset: geometry.safeAreaInsets.top,
                            scoreText: copy.score(gameManager.score),
                            problemText: gameManager.currentProblem
                        )
                    }

                    Spacer()

                    HStack(alignment: .bottom) {
                        if gameManager.gameStarted {
                            Button(action: {
                                gameManager.resetGame()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white.opacity(0.92))
                                    .padding(8)
                                    .background(Color.black.opacity(0.4), in: Circle())
                            }
                            .accessibilityLabel(copy.cancel)
                        }

                        Spacer()

                        if gameManager.gameStarted {
                            LifeBarHUD(
                                language: appSettings.language,
                                remainingLives: gameManager.remainingLives,
                                maximumLives: GameManager.maximumLives,
                                vehicleType: gameManager.vehicleType
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .zIndex(12)

                if gameManager.gameStarted {
                    TopSafeStripe(topInset: geometry.safeAreaInsets.top)
                        .zIndex(11)
                }

                if gameManager.gameOver {
                    VStack(spacing: 12) {
                        Text(copy.gameOver)
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.red)

                        Text(copy.finalScore(gameManager.score))
                            .font(.title2)
                            .foregroundColor(.white)

                        Text(
                            copy.roundAccuracy(
                                correct: gameManager.currentSessionCorrectAnswers,
                                attempts: gameManager.currentSessionAttempts
                            )
                        )
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                        if appSettings.automaticMissionSuggestions,
                           let mission = gameManager.recommendedMission,
                           appSettings.isSpecialMissionEnabled(mission) {
                            VStack(spacing: 8) {
                                Text(copy.recommendedMission)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(copy.specialMissionTitle(mission))
                                    .font(.headline.weight(.black))
                                    .foregroundColor(.white)
                                Button(copy.startMission) {
                                    gameManager.resetGame()
                                    gameManager.startSpecialMission(mission)
                                }
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(14)
                            .background(Color.blue.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Button(action: {
                            gameManager.resetGame()
                        }) {
                            Text(copy.playAgain)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 14)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(28)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 22))
                }

                if let celebration = gameManager.activeCelebration {
                    CelebrationVideoOverlay(
                        language: appSettings.language,
                        celebration: celebration,
                        soundEnabled: appSettings.soundEnabled
                    ) {
                        gameManager.finishCelebration()
                    }
                    .zIndex(40)
                }

                if let mission = gameManager.strategyIntroMission {
                    StrategyIntroAnimationView(
                        mission: mission,
                        language: appSettings.language,
                        accessibilityOptions: accessibilityOptions
                    ) {
                        gameManager.completeStrategyIntroAndStartMission()
                    }
                    .zIndex(55)
                }

                if let session = gameManager.activeSpecialMission,
                   let hint = gameManager.missionStrategyHint {
                    MissionHintOverlay(
                        title: copy.specialMissionTitle(session.mission),
                        hint: gameManager.bossFightState == .intro
                            ? copy.bossIncoming
                            : (session.phase == .unlockStrategy ? copy.specialMissionUnlockText(session.mission) : hint)
                    )
                    .zIndex(35)
                }

                if gameManager.missionCompleted,
                   let session = gameManager.activeSpecialMission {
                    MissionCompleteOverlay(
                        title: copy.specialMissionTitle(session.mission),
                        reward: copy.missionReward,
                        buttonTitle: copy.continueButton,
                        onContinue: {
                            gameManager.closeMissionCompletion()
                        }
                    )
                    .zIndex(50)
                }

                if !gameManager.gameStarted {
                    WelcomeOverlay(
                        appTitle: AppBrand.appTitle,
                        language: appSettings.language,
                        selectedMode: gameManager.gameMode,
                        selectedVehicle: gameManager.vehicleType,
                        availableVehicles: AppBrand.availableVehicles,
                        highScore: gameManager.highScore,
                        onSelectLanguage: { language in
                            appSettings.language = language
                        },
                        onSelectMode: { mode in
                            gameManager.setGameMode(mode)
                        },
                        onSelectVehicle: { vehicle in
                            gameManager.setVehicleType(vehicle)
                        },
                        onOpenSettings: {
                            showingSettings = true
                        },
                        onOpenAnalytics: {
                            showingAnalytics = true
                        },
                        onStart: {
                            gameManager.startGame()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                configureRuntimeSettings()
                gameManager.setupGame(size: geometry.size, reservedTopArea: reservedTopArea)
                gameManager.applyCurriculumSettings(appSettings.curriculumSettings)
            }
            .onChange(of: geometry.size) { _, newSize in
                gameManager.setupGame(size: newSize, reservedTopArea: reservedTopArea)
            }
            .onChange(of: geometry.safeAreaInsets.top) { _, newTopInset in
                gameManager.setupGame(size: geometry.size, reservedTopArea: newTopInset + 18)
            }
            .onChange(of: appSettings.curriculumSettings) { _, newSettings in
                gameManager.applyCurriculumSettings(newSettings)
            }
            .onChange(of: appSettings.soundEnabled) { _, _ in
                configureRuntimeSettings()
            }
            .onChange(of: appSettings.bossShootingEnabled) { _, _ in
                configureRuntimeSettings()
            }
            .onChange(of: gameManager.gameOver) { _, isGameOver in
                if isGameOver {
                    gameManager.updateMissionRecommendationIfNeeded(
                        automaticSuggestionsEnabled: appSettings.automaticMissionSuggestions,
                        missionEnabled: { appSettings.isSpecialMissionEnabled($0) }
                    )
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    configureRuntimeSettings()
                    gameManager.resumeFromAppBackground()
                case .inactive, .background:
                    gameManager.pauseForAppBackground()
                    soundManager.stopAllSounds()
                @unknown default:
                    break
                }
            }
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView(
                    language: appSettings.language,
                    stageSummaries: gameManager.analyticsStageSummaries(in: appSettings.language),
                    suggestions: gameManager.analyticsSuggestions(in: appSettings.language),
                    onResetStatistics: {
                        showingResetStatisticsConfirmation = true
                    }
                )
            }
            .sheet(isPresented: $showingSettings) {
                CurriculumSettingsView(
                    appSettings: appSettings,
                    onOpenMissions: {
                        showingSettings = false
                        DispatchQueue.main.async {
                            showingMissions = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingMissions) {
                SpecialMissionsView(
                    language: appSettings.language,
                    appSettings: appSettings,
                    progress: gameManager.specialMissionProgress,
                    recommendedMission: gameManager.recommendedMission,
                    onStartMission: { mission in
                        showingMissions = false
                        gameManager.startSpecialMission(mission)
                    }
                )
            }
            .alert(copy.resetStatisticsTitle, isPresented: $showingResetStatisticsConfirmation) {
                Button(copy.cancel, role: .cancel) {}
                Button(copy.reset, role: .destructive) {
                    gameManager.resetStatistics()
                }
            } message: {
                Text(copy.resetStatisticsMessage)
            }
        }
    }

    private var effectiveAccessibilityOptions: GameAccessibilityOptions {
        var options = appSettings.accessibilityOptions
        if systemReduceMotion {
            options.reduceMotionEffects = true
        }
        return options
    }

    private func configureRuntimeSettings() {
        soundManager.configure(soundEnabled: appSettings.soundEnabled)
        gameManager.configureSound(enabled: appSettings.soundEnabled)
        gameManager.configureBossShooting(enabled: appSettings.bossShootingEnabled)
    }
}

private struct TopGameHUD: View {
    let topInset: CGFloat
    let scoreText: String
    let problemText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                hudPill(scoreText)
                Spacer()
            }

            if !problemText.isEmpty {
                Text(problemText)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .multilineTextAlignment(.center)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .zIndex(14)
    }

    private func hudPill(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.black))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12), in: Capsule())
    }
}

private struct TopSafeStripe: View {
    let topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.16))
                .frame(height: topInset + 6)
            Spacer()
        }
        .ignoresSafeArea()
    }
}

private struct CelebrationVideoOverlay: View {
    let language: AppLanguage
    let celebration: CelebrationEvent
    let soundEnabled: Bool
    let onFinished: () -> Void

    @State private var player = AVPlayer()
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackObserver: NSObjectProtocol?

    private let videoURL = Bundle.main.url(forResource: "bomb", withExtension: "mp4")
    private let audioURL = Bundle.main.url(forResource: "bomb_explosion", withExtension: "wav")

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            if videoURL != nil {
                CelebrationPlayerView(player: player)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 72, weight: .black))
                        .foregroundStyle(.yellow, .orange)

                    Text(AppCopy(language: language).missingExplosionVideo)
                        .font(.title2.weight(.black))
                        .foregroundColor(.white)
                }
            }
        }
        .task(id: celebration.id) {
            await MainActor.run {
                startPlayback()
            }
        }
        .onDisappear {
            stopPlayback()
        }
    }

    @MainActor
    private func startPlayback() {
        stopPlayback()

        guard let videoURL else {
            DispatchQueue.main.async {
                onFinished()
            }
            return
        }

        let item = AVPlayerItem(url: videoURL)
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onFinished()
        }

        player.replaceCurrentItem(with: item)
        player.actionAtItemEnd = .pause
        playCelebrationAudio()
        player.play()
    }

    @MainActor
    private func stopPlayback() {
        player.pause()
        audioPlayer?.stop()
        audioPlayer = nil

        if let playbackObserver {
            NotificationCenter.default.removeObserver(playbackObserver)
            self.playbackObserver = nil
        }
    }

    @MainActor
    private func playCelebrationAudio() {
        guard soundEnabled, let audioURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Could not play celebration audio: \(error)")
        }
    }
}

private struct CelebrationPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        controller.player = player
    }
}

private struct ThemeFillView: View {
    let vehicleType: VehicleType

    var body: some View {
        switch vehicleType {
        case .jet:
            Color(red: 0.07, green: 0.27, blue: 0.58)
        case .tank, .unicorn:
            Color(red: 0.18, green: 0.42, blue: 0.14)
        }
    }
}

private struct WelcomeOverlay: View {
    let appTitle: String
    let language: AppLanguage
    let selectedMode: GameMode
    let selectedVehicle: VehicleType
    let availableVehicles: [VehicleType]
    let highScore: Int
    let onSelectLanguage: (AppLanguage) -> Void
    let onSelectMode: (GameMode) -> Void
    let onSelectVehicle: (VehicleType) -> Void
    let onOpenSettings: () -> Void
    let onOpenAnalytics: () -> Void
    let onStart: () -> Void

    var body: some View {
        let copy = AppCopy(language: language)

        ZStack {
            VStack(spacing: 22) {
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(AppLanguage.allCases) { option in
                            Button(action: {
                                onSelectLanguage(option)
                            }) {
                                Text(flag(for: option))
                                    .font(.system(size: 22))
                                    .frame(width: 38, height: 38)
                                    .background(
                                        language == option ? Color.blue : Color.white.opacity(0.16),
                                        in: Circle()
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(language == option ? 0.45 : 0.16), lineWidth: 1)
                                    )
                            }
                            .accessibilityLabel(accessibilityLanguageName(for: option))
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Text(appTitle)
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text(copy.chooseModeSubtitle)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Text(copy.highScore(highScore))
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: Capsule())

                VStack(alignment: .leading, spacing: 10) {
                    Text(copy.mode)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 12) {
                        ForEach(GameMode.allCases) { mode in
                            Button(action: {
                                onSelectMode(mode)
                            }) {
                                Text(mode.symbol)
                                    .font(.title2.weight(.black))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        selectedMode == mode ? Color.blue : Color.white.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 14)
                                    )
                            }
                        }
                    }
                }

                if availableVehicles.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.vehicle)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))

                        HStack(spacing: 12) {
                            ForEach(availableVehicles) { vehicle in
                                VehicleChoiceButton(
                                    vehicle: vehicle,
                                    isSelected: selectedVehicle == vehicle,
                                    action: {
                                        onSelectVehicle(vehicle)
                                    }
                                )
                            }
                        }
                    }
                }

                Button(action: onOpenSettings) {
                    Label(copy.settings, systemImage: "slider.horizontal.3")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onStart) {
                    Text(copy.startGame)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 360, minHeight: 430)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 28))

            Button(action: onOpenAnalytics) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(Color.blue.opacity(0.9), in: Circle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 24)
    }
    private func flag(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "🇬🇧"
        case .german:
            return "🇩🇪"
        }
    }

    private func accessibilityLanguageName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        }
    }
}

private struct CurriculumSettingsView: View {
    @ObservedObject var appSettings: AppSettings
    let onOpenMissions: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var activeHelpTopic: SettingsHelpTopic?

    private let tableOptions = Array(2...12)
    private let factorOptions = Array(2...12)

    var body: some View {
        let copy = AppCopy(language: appSettings.language)

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ParentTeacherGuideView(copy: copy)
                    } label: {
                        Label(copy.parentTeacherGuide, systemImage: "questionmark.circle.fill")
                    }
                } footer: {
                    Text(copy.settingsHelpFooter)
                }

                Section {
                    Picker(copy.learningProfile, selection: learningProfileBinding) {
                        ForEach(LearningProfile.allCases) { profile in
                            Text(copy.learningProfileTitle(profile)).tag(profile)
                        }
                    }

                    Text(copy.learningProfileDescription(appSettings.curriculumSettings.learningProfile))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    SettingsHelpHeader(
                        title: copy.learningProfile,
                        topic: .learningProfile,
                        activeTopic: $activeHelpTopic
                    )
                } footer: {
                    Text(copy.settingsFooter)
                }

                Section {
                    Picker(copy.arithmeticFocus, selection: arithmeticFocusBinding) {
                        ForEach(ArithmeticFocus.allCases) { focus in
                            Text(copy.arithmeticFocusTitle(focus)).tag(focus)
                        }
                    }

                    Toggle(copy.includeBasicReview, isOn: includeBasicReviewBinding)

                    Text(copy.arithmeticFocusDescription(appSettings.curriculumSettings.arithmeticFocus))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    SettingsHelpHeader(
                        title: copy.arithmetic,
                        topic: .arithmeticFocus,
                        activeTopic: $activeHelpTopic
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.multiplicationTablesTitle)
                            .font(.subheadline.weight(.bold))

                        NumberSelectionGrid(
                            values: tableOptions,
                            selectedValues: appSettings.curriculumSettings.normalizedMultiplicationTables,
                            onToggle: toggleTable
                        )
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(copy.multiplicationFactorsTitle)
                            .font(.subheadline.weight(.bold))

                        NumberSelectionGrid(
                            values: factorOptions,
                            selectedValues: appSettings.curriculumSettings.normalizedMultiplicationFactors,
                            onToggle: toggleFactor
                        )
                    }
                    .padding(.vertical, 4)

                    Toggle(copy.reversedFacts, isOn: reversedFactsBinding)
                } header: {
                    SettingsHelpHeader(
                        title: copy.multiplication,
                        topic: .multiplicationDivision,
                        activeTopic: $activeHelpTopic
                    )
                }

                Section(copy.gameOptions) {
                    Toggle(copy.soundEffects, isOn: soundEnabledBinding)
                    Toggle(copy.bossShooting, isOn: bossShootingEnabledBinding)
                }

                Section {
                    Toggle(copy.enableSpecialMissions, isOn: specialMissionsEnabledBinding)
                    Toggle(copy.automaticMissionSuggestions, isOn: automaticMissionSuggestionsBinding)

                    Button {
                        dismiss()
                        onOpenMissions()
                    } label: {
                        Label(copy.specialMissions, systemImage: "star.circle.fill")
                    }

                    ForEach(SpecialMissionID.allCases) { mission in
                        Toggle(
                            copy.specialMissionTitle(mission),
                            isOn: specialMissionEnabledBinding(for: mission)
                        )
                    }
                } header: {
                    SettingsHelpHeader(
                        title: copy.specialMissions,
                        topic: .specialMissions,
                        activeTopic: $activeHelpTopic
                    )
                } footer: {
                    Text(copy.missionSettingsFooter)
                }

                Section {
                    Toggle(copy.reduceMotionEffects, isOn: reduceMotionEffectsBinding)
                    Toggle(copy.highContrastMode, isOn: highContrastModeBinding)
                    Toggle(copy.largeAnswerText, isOn: largeAnswerTextBinding)
                } header: {
                    SettingsHelpHeader(
                        title: copy.accessibility,
                        topic: .accessibility,
                        activeTopic: $activeHelpTopic
                    )
                } footer: {
                    Text(copy.accessibilityFooter)
                }
            }
            .navigationTitle(copy.settings)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.done) {
                        dismiss()
                    }
                }
            }
            .alert(item: $activeHelpTopic) { topic in
                Alert(
                    title: Text(copy.settingsHelpTitle),
                    message: Text(copy.settingsHelpMessage(topic)),
                    dismissButton: .default(Text(copy.done))
                )
            }
        }
    }

    private var learningProfileBinding: Binding<LearningProfile> {
        Binding(
            get: { appSettings.curriculumSettings.learningProfile },
            set: { appSettings.setLearningProfile($0) }
        )
    }

    private var arithmeticFocusBinding: Binding<ArithmeticFocus> {
        Binding(
            get: { appSettings.curriculumSettings.arithmeticFocus },
            set: { newValue in
                appSettings.updateCurriculum { settings in
                    settings.arithmeticFocus = newValue
                }
            }
        )
    }

    private var includeBasicReviewBinding: Binding<Bool> {
        Binding(
            get: { appSettings.curriculumSettings.includeBasicReview },
            set: { newValue in
                appSettings.updateCurriculum { settings in
                    settings.includeBasicReview = newValue
                }
            }
        )
    }

    private var reversedFactsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.curriculumSettings.multiplicationIncludeReversedFacts },
            set: { newValue in
                appSettings.updateCurriculum { settings in
                    settings.multiplicationIncludeReversedFacts = newValue
                }
            }
        )
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.soundEnabled },
            set: { appSettings.soundEnabled = $0 }
        )
    }

    private var bossShootingEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.bossShootingEnabled },
            set: { appSettings.bossShootingEnabled = $0 }
        )
    }

    private var reduceMotionEffectsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.reduceMotionEffects },
            set: { appSettings.reduceMotionEffects = $0 }
        )
    }

    private var highContrastModeBinding: Binding<Bool> {
        Binding(
            get: { appSettings.highContrastMode },
            set: { appSettings.highContrastMode = $0 }
        )
    }

    private var largeAnswerTextBinding: Binding<Bool> {
        Binding(
            get: { appSettings.largeAnswerText },
            set: { appSettings.largeAnswerText = $0 }
        )
    }

    private var specialMissionsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.specialMissionsEnabled },
            set: { appSettings.specialMissionsEnabled = $0 }
        )
    }

    private var automaticMissionSuggestionsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.automaticMissionSuggestions },
            set: { appSettings.automaticMissionSuggestions = $0 }
        )
    }

    private func specialMissionEnabledBinding(for mission: SpecialMissionID) -> Binding<Bool> {
        Binding(
            get: { appSettings.enabledSpecialMissionIDs.contains(mission) },
            set: { appSettings.setSpecialMission(mission, enabled: $0) }
        )
    }

    private func toggleTable(_ table: Int) {
        appSettings.updateCurriculum { settings in
            if settings.multiplicationTables.contains(table) {
                if settings.normalizedMultiplicationTables.count > 1 {
                    settings.multiplicationTables.removeAll { $0 == table }
                }
            } else {
                settings.multiplicationTables.append(table)
            }
        }
    }

    private func toggleFactor(_ factor: Int) {
        appSettings.updateCurriculum { settings in
            if settings.multiplicationFactors.contains(factor) {
                if settings.normalizedMultiplicationFactors.count > 1 {
                    settings.multiplicationFactors.removeAll { $0 == factor }
                }
            } else {
                settings.multiplicationFactors.append(factor)
            }
        }
    }
}

private struct SettingsHelpHeader: View {
    let title: String
    let topic: SettingsHelpTopic
    @Binding var activeTopic: SettingsHelpTopic?

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Button {
                activeTopic = topic
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) help")
        }
    }
}

private struct ParentTeacherGuideView: View {
    let copy: AppCopy

    var body: some View {
        List {
            Section {
                Text(copy.parentTeacherGuideIntro)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section(copy.gameModesTitle) {
                ForEach(GameMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.title(in: copy.language))
                            .font(.headline)
                        Text(copy.modeDescription(for: mode))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(copy.specialMissions) {
                Text(copy.specialMissionsGuide)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(copy.accessibility) {
                Text(copy.accessibilityGuide)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(copy.parentTeacherGuide)
    }
}

private struct NumberSelectionGrid: View {
    let values: [Int]
    let selectedValues: [Int]
    let onToggle: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button(action: {
                    onToggle(value)
                }) {
                    Text("\(value)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(selectedValues.contains(value) ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            selectedValues.contains(value) ? Color.blue : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SpecialMissionsView: View {
    let language: AppLanguage
    @ObservedObject var appSettings: AppSettings
    let progress: [SpecialMissionID: SpecialMissionProgress]
    let recommendedMission: SpecialMissionID?
    let onStartMission: (SpecialMissionID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let copy = AppCopy(language: language)

        NavigationStack {
            List {
                Section {
                    Toggle(copy.enableSpecialMissions, isOn: specialMissionsEnabledBinding)
                    Toggle(copy.automaticMissionSuggestions, isOn: automaticMissionSuggestionsBinding)
                }

                Section(copy.specialMissions) {
                    ForEach(SpecialMissionID.allCases) { mission in
                        SpecialMissionRow(
                            copy: copy,
                            mission: mission,
                            progress: progress[mission],
                            isEnabled: appSettings.isSpecialMissionEnabled(mission),
                            isRecommended: mission == recommendedMission,
                            onStart: {
                                onStartMission(mission)
                            }
                        )
                    }
                }
            }
            .navigationTitle(copy.specialMissions)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.done) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var specialMissionsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appSettings.specialMissionsEnabled },
            set: { appSettings.specialMissionsEnabled = $0 }
        )
    }

    private var automaticMissionSuggestionsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.automaticMissionSuggestions },
            set: { appSettings.automaticMissionSuggestions = $0 }
        )
    }
}

private struct SpecialMissionRow: View {
    let copy: AppCopy
    let mission: SpecialMissionID
    let progress: SpecialMissionProgress?
    let isEnabled: Bool
    let isRecommended: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: mission.badgeSymbol)
                    .font(.title2.weight(.black))
                    .foregroundColor(progress?.missionCompleted == true ? .yellow : .blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.specialMissionTitle(mission))
                        .font(.headline.weight(.black))

                    Text(copy.specialMissionDescription(mission))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack {
                if progress?.missionCompleted == true {
                    Label(copy.completed, systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.green)
                }

                if isRecommended {
                    Label(copy.recommendedMission, systemImage: "sparkle")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.orange)
                }

                Spacer()

                Button(copy.startMission, action: onStart)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isEnabled)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MissionHintOverlay: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.white.opacity(0.85))

            Text(hint)
                .font(.title3.weight(.black))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }
}

private struct MissionCompleteOverlay: View {
    let title: String
    let reward: String
    let buttonTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 58, weight: .black))
                .foregroundStyle(.yellow, .orange)

            Text(title)
                .font(.title2.weight(.black))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(reward)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Button(buttonTitle, action: onContinue)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(26)
        .background(Color.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 24))
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct AnalyticsView: View {
    let language: AppLanguage
    let stageSummaries: [AnalyticsStageSummary]
    let suggestions: [String]
    let onResetStatistics: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let copy = AppCopy(language: language)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(copy.suggestions)
                            .font(.title3.weight(.black))

                        if suggestions.isEmpty {
                            Text(copy.noAnalyticsYet)
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }

                    if !practiceRecommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(copy.recommendedPractice)
                                .font(.title3.weight(.black))

                            ForEach(practiceRecommendations) { recommendation in
                                AnalyticsPracticeCard(recommendation: recommendation)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(copy.stageSummary)
                            .font(.title3.weight(.black))

                        ForEach(stageSummaries) { summary in
                            AnalyticsSummaryCard(language: language, summary: summary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(copy.analyticsTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(copy.resetStats, role: .destructive) {
                        dismiss()
                        onResetStatistics()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(copy.done) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var practiceRecommendations: [AnalyticsPracticeRecommendation] {
        stageSummaries.compactMap { summary in
            guard summary.attempts >= 6 else { return nil }

            if summary.accuracy < 0.75 {
                return .init(
                    priority: Int((1 - summary.accuracy) * 1000),
                    title: summary.title,
                    headline: localizedPracticeHeadline(kind: .accuracy),
                    detail: localizedPracticeDetail(for: summary, kind: .accuracy),
                    action: localizedPracticeAction(for: summary, kind: .accuracy)
                )
            }

            if summary.accuracy >= 0.82, summary.averageResponseTimeMs >= 3600 {
                return .init(
                    priority: Int(summary.averageResponseTimeMs),
                    title: summary.title,
                    headline: localizedPracticeHeadline(kind: .fluency),
                    detail: localizedPracticeDetail(for: summary, kind: .fluency),
                    action: localizedPracticeAction(for: summary, kind: .fluency)
                )
            }

            if summary.retrySuccessRate < 0.55, summary.attempts >= 8 {
                return .init(
                    priority: Int((1 - summary.retrySuccessRate) * 900),
                    title: summary.title,
                    headline: localizedPracticeHeadline(kind: .retry),
                    detail: localizedPracticeDetail(for: summary, kind: .retry),
                    action: localizedPracticeAction(for: summary, kind: .retry)
                )
            }

            return nil
        }
        .sorted { $0.priority > $1.priority }
        .prefix(4)
        .map { $0 }
    }

    private func localizedPracticeHeadline(kind: AnalyticsPracticeKind) -> String {
        switch (language, kind) {
        case (.english, .accuracy):
            return "Needs first-try accuracy"
        case (.english, .fluency):
            return "Needs faster recall"
        case (.english, .retry):
            return "Needs stronger recovery after mistakes"
        case (.german, .accuracy):
            return "Mehr Sicherheit im Erstversuch"
        case (.german, .fluency):
            return "Schnelleres Abrufen üben"
        case (.german, .retry):
            return "Nach Fehlern noch unsicher"
        }
    }

    private func localizedPracticeDetail(for summary: AnalyticsStageSummary, kind: AnalyticsPracticeKind) -> String {
        switch (language, kind) {
        case (.english, .accuracy):
            return "First-try accuracy: \(percent(summary.accuracy))."
        case (.english, .fluency):
            return "Average answer time: \(seconds(summary.averageResponseTimeMs))."
        case (.english, .retry):
            return "Correct after a mistake: \(percent(summary.retrySuccessRate))."
        case (.german, .accuracy):
            return "Trefferquote im Erstversuch: \(percent(summary.accuracy))."
        case (.german, .fluency):
            return "Durchschnittliche Antwortzeit: \(seconds(summary.averageResponseTimeMs))."
        case (.german, .retry):
            return "Richtig nach einem Fehler: \(percent(summary.retrySuccessRate))."
        }
    }

    private func localizedPracticeAction(for summary: AnalyticsStageSummary, kind: AnalyticsPracticeKind) -> String {
        switch (language, kind) {
        case (.english, .accuracy):
            return "Repeat short sets of this exact skill."
        case (.english, .fluency):
            return "Keep this skill level and aim for quicker answers."
        case (.english, .retry):
            return "Repeat the same skill right after an error."
        case (.german, .accuracy):
            return "Kurze Wiederholungen genau dieses Bereichs einplanen."
        case (.german, .fluency):
            return "Bei diesem Niveau bleiben und auf schnelleres Antworten zielen."
        case (.german, .retry):
            return "Nach einem Fehler genau dieselbe Kompetenz direkt wiederholen."
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.1fs", value / 1000)
    }
}

private enum AnalyticsPracticeKind {
    case accuracy
    case fluency
    case retry
}

private struct AnalyticsPracticeRecommendation: Identifiable {
    let id = UUID()
    let priority: Int
    let title: String
    let headline: String
    let detail: String
    let action: String
}

private struct AnalyticsPracticeCard: View {
    let recommendation: AnalyticsPracticeRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recommendation.title)
                .font(.headline.weight(.bold))

            Text(recommendation.headline)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Text(recommendation.detail)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(recommendation.action)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct AnalyticsSummaryCard: View {
    let language: AppLanguage
    let summary: AnalyticsStageSummary

    var body: some View {
        let copy = AppCopy(language: language)
        let assessment = localizedAssessment

        VStack(alignment: .leading, spacing: 10) {
            Text(summary.title)
                .font(.headline.weight(.bold))

            HStack {
                metric(title: copy.accuracy, value: percent(summary.accuracy))
                Spacer()
                metric(title: copy.averageTime, value: seconds(summary.averageResponseTimeMs))
                Spacer()
                metric(title: copy.retry, value: percent(summary.retrySuccessRate))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.attempts(summary.attempts))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                Text("\(copy.goodAt): \(assessment.strength)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)

                Text("\(copy.practiceMore): \(assessment.practice)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func seconds(_ value: Double) -> String {
        String(format: "%.1fs", value / 1000)
    }

    private var localizedAssessment: (strength: String, practice: String) {
        switch language {
        case .english:
            return (englishStrength, englishPractice)
        case .german:
            return (germanStrength, germanPractice)
        }
    }

    private var englishStrength: String {
        if summary.accuracy >= 0.9, summary.averageResponseTimeMs <= 3000 {
            return "fast and secure"
        }

        if summary.accuracy >= 0.82 {
            return "first answers are usually right"
        }

        if summary.retrySuccessRate >= 0.65, summary.attempts >= 8 {
            return "mistakes are often corrected right away"
        }

        return "basic understanding is there"
    }

    private var englishPractice: String {
        if summary.accuracy < 0.75 {
            return "Needs more first-try accuracy."
        }

        if summary.averageResponseTimeMs > 3600, summary.accuracy >= 0.82 {
            return "Needs faster recall."
        }

        if summary.retrySuccessRate < 0.55, summary.attempts >= 8 {
            return "Needs stronger correction after mistakes."
        }

        return "Only light review needed."
    }

    private var germanStrength: String {
        if summary.accuracy >= 0.9, summary.averageResponseTimeMs <= 3000 {
            return "schnell und sicher"
        }

        if summary.accuracy >= 0.82 {
            return "die erste Antwort ist meist richtig"
        }

        if summary.retrySuccessRate >= 0.65, summary.attempts >= 8 {
            return "Fehler werden oft direkt korrigiert"
        }

        return "Grundverstaendnis ist vorhanden"
    }

    private var germanPractice: String {
        if summary.accuracy < 0.75 {
            return "Mehr Sicherheit im Erstversuch nötig."
        }

        if summary.averageResponseTimeMs > 3600, summary.accuracy >= 0.82 {
            return "Schnelleres Abrufen nötig."
        }

        if summary.retrySuccessRate < 0.55, summary.attempts >= 8 {
            return "Nach Fehlern mehr Stabilität nötig."
        }

        return "Nur leichte Wiederholung nötig."
    }
}

private struct BackgroundView: View {
    let vehicleType: VehicleType
    let size: CGSize

    var body: some View {
        ZStack(alignment: .bottom) {
            switch vehicleType {
            case .jet:
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.07, green: 0.27, blue: 0.58), Color.cyan]),
                    startPoint: .top,
                    endPoint: .bottom
                )

            case .tank, .unicorn:
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.56, green: 0.80, blue: 0.48), Color(red: 0.30, green: 0.56, blue: 0.24)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            if vehicleType == .tank || vehicleType == .unicorn {
                VStack(spacing: 0) {
                    Spacer()

                    ZStack(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(red: 0.18, green: 0.42, blue: 0.14))
                            .frame(height: 150)

                        HStack(spacing: 18) {
                            ForEach(0..<8, id: \.self) { index in
                                BushView(size: index.isMultiple(of: 2) ? 1.0 : 0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 14)
                    }
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }
}

private struct VehicleChoiceButton: View {
    let vehicle: VehicleType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if vehicle == .jet {
                    if UIImage(named: "Aircraft") != nil {
                        Image("Aircraft")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "airplane")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .padding(14)
                    }
                } else if vehicle == .tank {
                    if UIImage(named: "Tank") != nil {
                        Image("Tank")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "shield.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .padding(14)
                    }
                } else {
                    if UIImage(named: "Unicorn") != nil {
                        Image("Unicorn")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "sparkles")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .padding(14)
                    }
                }
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                isSelected ? Color.green : Color.white.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
    }
}

private struct BushView: View {
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(Color(red: 0.16, green: 0.42, blue: 0.12))
                .frame(width: 42 * size, height: 42 * size)
                .offset(x: -10 * size)

            Circle()
                .fill(Color(red: 0.20, green: 0.50, blue: 0.14))
                .frame(width: 52 * size, height: 52 * size)

            Circle()
                .fill(Color(red: 0.14, green: 0.36, blue: 0.10))
                .frame(width: 40 * size, height: 40 * size)
                .offset(x: 14 * size)
        }
        .frame(width: 64 * size, height: 40 * size)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
