import SwiftUI
import UIKit

struct FlyingNumberView: View {
    let number: FlyingNumber
    let vehicleType: VehicleType
    let accessibilityOptions: GameAccessibilityOptions
    let onTap: () -> Void

    private let visibleMissileScale: CGFloat = 1.42

    private var answerFontSize: CGFloat {
        accessibilityOptions.largeAnswerText ? 30 : 24
    }
    
    private var containerSize: CGSize {
        switch vehicleType {
        case .unicorn:
            return CGSize(width: 138, height: 182)
        case .jet, .tank:
            return CGSize(width: GameManager.missileWidth, height: GameManager.missileHeight)
        }
    }

    @ViewBuilder
    private var numberOverlay: some View {
        if accessibilityOptions.highContrastMode {
            Text("\(number.value)")
                .font(.system(size: accessibilityOptions.largeAnswerText ? 30 : 24, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(Color.black, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: accessibilityOptions.reduceMotionEffects ? 0 : 3, y: 1)
                .offset(y: vehicleType == .unicorn ? 8 : 14)
        } else if vehicleType == .unicorn {
            ZStack {
                if !accessibilityOptions.reduceMotionEffects {
                    Circle()
                        .fill(Color(red: 0.98, green: 0.70, blue: 0.16).opacity(0.28))
                        .frame(width: 54, height: 54)
                        .blur(radius: 14)

                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(index.isMultiple(of: 2) ? Color.yellow : Color.orange)
                            .frame(width: index.isMultiple(of: 3) ? 3 : 4, height: index.isMultiple(of: 3) ? 3 : 4)
                            .offset(
                                x: [ -18.0, -5.0, 12.0, 21.0, 15.0, -12.0, 8.0, -22.0 ][index],
                                y: [ -10.0, -18.0, -13.0, 0.0, 14.0, 18.0, 21.0, 6.0 ][index]
                            )
                            .shadow(color: Color.orange.opacity(0.9), radius: 5)
                    }
                }

                Text("\(number.value)")
                    .font(.system(size: answerFontSize, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.98, blue: 0.88),
                                Color(red: 1.00, green: 0.88, blue: 0.38),
                                Color(red: 0.95, green: 0.58, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 1.00, green: 0.78, blue: 0.16).opacity(0.95), radius: 6)
                    .shadow(color: Color.orange.opacity(0.85), radius: 10)
                    .shadow(color: Color.black.opacity(0.4), radius: 1, y: 1)
            }
            .offset(x: 12, y: 8)
        } else {
            Text("\(number.value)")
                .font(.system(size: accessibilityOptions.largeAnswerText ? 27 : 20, weight: .black, design: .rounded))
                .fontWeight(.black)
                .foregroundColor(.red)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.92), in: Capsule())
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .offset(y: 14)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if vehicleType == .unicorn, UIImage(named: "Witch") != nil {
                    Image("Witch")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 126, height: 170)
                        .shadow(color: .purple.opacity(0.45), radius: accessibilityOptions.reduceMotionEffects ? 0 : 10, y: 6)
                        .offset(y: -4)
                } else if UIImage(named: "Missile") != nil {
                    Image("Missile")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: GameManager.missileWidth * visibleMissileScale,
                        height: GameManager.missileHeight * visibleMissileScale
                        )
                        .frame(width: GameManager.missileWidth, height: GameManager.missileHeight)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.20, green: 0.62, blue: 0.86), Color(red: 0.05, green: 0.36, blue: 0.67)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 76, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.white.opacity(0.55), lineWidth: 2)
                        )
                }

                numberOverlay
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .contentShape(Rectangle())
        .position(number.position)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Answer \(number.value)")
        .accessibilityHint("Double tap to choose this answer")
        .accessibilityAddTraits(.isButton)
    }
}

struct ExplosionView: View {
    let explosion: Explosion
    let accessibilityOptions: GameAccessibilityOptions
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(explosion.opacity),
                            Color.yellow.opacity(explosion.opacity * 0.95),
                            Color.orange.opacity(explosion.opacity * 0.7),
                            Color.red.opacity(explosion.opacity * 0.35),
                            .clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 55 * explosion.scale
                    )
                )
                .frame(width: 110 * explosion.scale, height: 110 * explosion.scale)

            if !accessibilityOptions.reduceMotionEffects {
                ForEach(0..<14, id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? Color.yellow : Color.orange)
                        .frame(width: 5, height: 30 * explosion.scale)
                        .offset(y: -(28 * explosion.scale))
                        .rotationEffect(.degrees(Double(index) * (360.0 / 14.0)))
                        .opacity(explosion.opacity)
                }
            }

            Circle()
                .stroke(Color.yellow.opacity(explosion.opacity), lineWidth: 4)
                .frame(width: 75 * explosion.scale, height: 75 * explosion.scale)

            Circle()
                .fill(Color.white.opacity(explosion.opacity * 0.95))
                .frame(width: 18 * explosion.scale, height: 18 * explosion.scale)
        }
        .position(explosion.position)
        .blendMode(accessibilityOptions.reduceMotionEffects ? .normal : .screen)
        .accessibilityHidden(true)
    }
}

struct BossView: View {
    let boss: BossEntity
    let state: BossFightState
    let vehicleType: VehicleType
    let accessibilityOptions: GameAccessibilityOptions
    @State private var isHovering = false

    private var bossSize: CGSize {
        switch vehicleType {
        case .tank:
            return CGSize(width: 150, height: 190)
        case .jet:
            return CGSize(width: 190, height: 160)
        case .unicorn:
            return CGSize(width: 210, height: 170)
        }
    }

    private var yOffset: CGFloat {
        switch state {
        case .inactive:
            return -260
        case .intro:
            return -80
        case .active, .damaged, .blocked:
            return isHovering && !accessibilityOptions.reduceMotionEffects ? 8 : 0
        case .defeated, .reward:
            return -20
        }
    }

    private var xOffset: CGFloat {
        guard !accessibilityOptions.reduceMotionEffects else { return 0 }

        switch state {
        case .damaged:
            return -8
        case .blocked:
            return 12
        default:
            return 0
        }
    }

    private var opacity: Double {
        switch state {
        case .inactive:
            return 0
        case .defeated:
            return 0.25
        default:
            return 1
        }
    }

    private var rotation: Angle {
        switch vehicleType {
        case .tank, .jet:
            return .degrees(180)
        case .unicorn:
            return .zero
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<boss.definition.maxHP, id: \.self) { index in
                    Image(systemName: index < boss.currentHP ? "heart.fill" : "heart")
                        .font(.caption.weight(.black))
                        .foregroundColor(index < boss.currentHP ? .red : .white.opacity(0.55))
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.58), in: Capsule())

            ZStack {
                if state == .blocked {
                    Circle()
                        .stroke(Color.cyan.opacity(0.75), lineWidth: 5)
                        .frame(width: bossSize.width * 1.08, height: bossSize.height * 0.8)
                        .blur(radius: accessibilityOptions.reduceMotionEffects ? 0 : 1.5)
                }

                Image(boss.definition.spriteName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: bossSize.width, height: bossSize.height)
                    .rotationEffect(rotation)
                    .brightness(state == .damaged ? 0.42 : 0)
                    .saturation(state == .defeated ? 0.2 : 1)
                    .shadow(color: .red.opacity(0.45), radius: accessibilityOptions.reduceMotionEffects ? 0 : 18)
                    .id(boss.animationToken)

                if state == .defeated && !accessibilityOptions.reduceMotionEffects {
                    ForEach(0..<18, id: \.self) { index in
                        Capsule()
                            .fill(index.isMultiple(of: 2) ? Color.yellow : Color.orange)
                            .frame(width: 5, height: 42)
                            .offset(y: -58)
                            .rotationEffect(.degrees(Double(index) * 20))
                            .blendMode(.screen)
                    }
                }
            }
        }
        .offset(x: xOffset, y: yOffset)
        .scaleEffect(state == .defeated ? 1.08 : 1)
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 92)
        .animation(.spring(response: 0.42, dampingFraction: 0.65), value: state)
        .animation(.spring(response: 0.28, dampingFraction: 0.45), value: boss.animationToken)
        .onAppear {
            if !accessibilityOptions.reduceMotionEffects {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    isHovering = true
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mission boss, \(boss.currentHP) hit points remaining")
    }

}

enum StrategyType {
    case friendsOf10
    case bridgingThrough10
    case nearDoubles
    case countingUp
    case nineTrick

    init(mission: SpecialMissionID) {
        switch mission {
        case .friendsOf10:
            self = .friendsOf10
        case .bridgingThrough10:
            self = .bridgingThrough10
        case .doublesNearDoubles:
            self = .nearDoubles
        case .countingUp:
            self = .countingUp
        case .nineTrick:
            self = .nineTrick
        }
    }
}

struct StrategyAnimationStep: Identifiable, Equatable {
    let id = UUID()
    let displayedExpression: String
    let highlightedElements: [String]
    let movingElements: [String]
    let arrows: [String]
    let numberLineJumps: [StrategyNumberLineJump]
    let duration: TimeInterval
    let optionalSoundEffect: String?
    let optionalFinalAnswer: String?

    init(
        displayedExpression: String,
        highlightedElements: [String] = [],
        movingElements: [String] = [],
        arrows: [String] = [],
        numberLineJumps: [StrategyNumberLineJump] = [],
        duration: TimeInterval = 0.7,
        optionalSoundEffect: String? = nil,
        optionalFinalAnswer: String? = nil
    ) {
        self.displayedExpression = displayedExpression
        self.highlightedElements = highlightedElements
        self.movingElements = movingElements
        self.arrows = arrows
        self.numberLineJumps = numberLineJumps
        self.duration = duration
        self.optionalSoundEffect = optionalSoundEffect
        self.optionalFinalAnswer = optionalFinalAnswer
    }
}

struct StrategyNumberLineJump: Identifiable, Equatable {
    let id = UUID()
    let from: Int
    let to: Int
    let label: String
}

struct StrategyAnimationSequence {
    let strategyType: StrategyType
    let title: String
    let iconName: String
    let steps: [StrategyAnimationStep]
}

enum StrategyAnimationFactory {
    static func sequence(for strategyType: StrategyType, language: AppLanguage) -> StrategyAnimationSequence {
        switch strategyType {
        case .friendsOf10:
            return StrategyAnimationSequence(
                strategyType: strategyType,
                title: language == .german ? "Mach 10" : "Make 10",
                iconName: "star.circle.fill",
                steps: [
                    StrategyAnimationStep(displayedExpression: "8 + ? = 10", highlightedElements: ["?"], duration: 0.85),
                    StrategyAnimationStep(
                        displayedExpression: "8 + 2 = 10",
                        highlightedElements: ["2"],
                        movingElements: ["2"],
                        arrows: [language == .german ? "nach unten" : "down"],
                        duration: 0.8
                    ),
                    StrategyAnimationStep(displayedExpression: "8 + 2 = 10", highlightedElements: ["10"], duration: 0.8, optionalFinalAnswer: "10")
                ]
            )
        case .bridgingThrough10:
            return StrategyAnimationSequence(
                strategyType: strategyType,
                title: language == .german ? "Sprung zur 10" : "Jump to 10",
                iconName: "arrow.triangle.turn.up.right.circle.fill",
                steps: bridgeSteps(left: 8, right: 5, split: 2, rest: 3) +
                    bridgeSteps(left: 7, right: 6, split: 3, rest: 3)
            )
        case .nearDoubles:
            return StrategyAnimationSequence(
                strategyType: strategyType,
                title: language == .german ? "Zwillinge" : "Twins",
                iconName: "equal.circle.fill",
                steps: nearDoubleSteps(base: 7, result: 14) +
                    nearDoubleSteps(base: 4, result: 8)
            )
        case .countingUp:
            return StrategyAnimationSequence(
                strategyType: strategyType,
                title: language == .german ? "Hochzählen" : "Count Up",
                iconName: "arrow.up.forward.circle.fill",
                steps: countUpSteps(start: 8, target: 13, firstJump: 2, secondJump: 3) +
                    countUpSteps(start: 9, target: 15, firstJump: 1, secondJump: 5)
            )
        case .nineTrick:
            return StrategyAnimationSequence(
                strategyType: strategyType,
                title: "9-Trick",
                iconName: "9.circle.fill",
                steps: [
                    StrategyAnimationStep(displayedExpression: "24 + 9", highlightedElements: ["9"], duration: 0.65),
                    StrategyAnimationStep(displayedExpression: "24 + (10 - 1)", highlightedElements: ["10", "- 1"], movingElements: ["10"], duration: 0.75),
                    StrategyAnimationStep(displayedExpression: "24 + 10", highlightedElements: ["10"], duration: 0.65),
                    StrategyAnimationStep(displayedExpression: "34", highlightedElements: ["34"], duration: 0.6),
                    StrategyAnimationStep(
                        displayedExpression: "33",
                        highlightedElements: ["33"],
                        arrows: [language == .german ? "1 zurück" : "back 1"],
                        duration: 0.75,
                        optionalFinalAnswer: "33"
                    )
                ]
            )
        }
    }

    private static func bridgeSteps(left: Int, right: Int, split: Int, rest: Int) -> [StrategyAnimationStep] {
        let answer = left + right
        return [
            StrategyAnimationStep(displayedExpression: "\(left) + \(right)", highlightedElements: ["\(right)"], duration: 0.55),
            StrategyAnimationStep(displayedExpression: "\(left) + (\(split) + \(rest))", highlightedElements: ["\(split)", "\(rest)"], movingElements: ["\(split)"], duration: 0.8),
            StrategyAnimationStep(displayedExpression: "(\(left) + \(split)) + \(rest)", highlightedElements: ["\(left) + \(split)"], arrows: ["-> 10"], duration: 0.8),
            StrategyAnimationStep(displayedExpression: "10 + \(rest)", highlightedElements: ["10"], duration: 0.7),
            StrategyAnimationStep(displayedExpression: "\(answer)", highlightedElements: ["\(answer)"], duration: 0.65, optionalFinalAnswer: "\(answer)")
        ]
    }

    private static func nearDoubleSteps(base: Int, result: Int) -> [StrategyAnimationStep] {
        [
            StrategyAnimationStep(displayedExpression: "\(base) + \(base) = \(result)", highlightedElements: ["\(result)"], duration: 0.85),
            StrategyAnimationStep(displayedExpression: "\(base) + \(base + 1)", highlightedElements: ["\(base + 1)"], duration: 0.55),
            StrategyAnimationStep(displayedExpression: "\(base) + (\(base) + 1)", highlightedElements: ["\(base)", "+ 1"], movingElements: ["1"], duration: 0.8),
            StrategyAnimationStep(displayedExpression: "\(base) + \(base) + 1", highlightedElements: ["\(base) + \(base)"], duration: 0.7),
            StrategyAnimationStep(displayedExpression: "\(result) + 1", highlightedElements: ["\(result)"], duration: 0.65),
            StrategyAnimationStep(displayedExpression: "\(result + 1)", highlightedElements: ["\(result + 1)"], duration: 0.65, optionalFinalAnswer: "\(result + 1)")
        ]
    }

    private static func countUpSteps(start: Int, target: Int, firstJump: Int, secondJump: Int) -> [StrategyAnimationStep] {
        let firstStop = start + firstJump
        return [
            StrategyAnimationStep(
                displayedExpression: "\(target) - \(start)",
                highlightedElements: ["\(start)", "\(target)"],
                numberLineJumps: [StrategyNumberLineJump(from: start, to: target, label: "")],
                duration: 0.75
            ),
            StrategyAnimationStep(
                displayedExpression: "\(start) -> \(firstStop)    +\(firstJump)",
                highlightedElements: ["+\(firstJump)"],
                arrows: ["->"],
                numberLineJumps: [StrategyNumberLineJump(from: start, to: firstStop, label: "+\(firstJump)")],
                duration: 1.0
            ),
            StrategyAnimationStep(
                displayedExpression: "\(firstStop) -> \(target)    +\(secondJump)",
                highlightedElements: ["+\(secondJump)"],
                arrows: ["->"],
                numberLineJumps: [StrategyNumberLineJump(from: firstStop, to: target, label: "+\(secondJump)")],
                duration: 1.0
            ),
            StrategyAnimationStep(
                displayedExpression: "\(firstJump) + \(secondJump) = \(firstJump + secondJump)",
                highlightedElements: ["\(firstJump + secondJump)"],
                duration: 0.9,
                optionalFinalAnswer: "\(firstJump + secondJump)"
            )
        ]
    }
}

private enum StrategyLessonVisual: Equatable {
    case tenFrame(left: Int, right: Int, moved: Int)
    case dotRows(top: Int, bottom: Int, extra: Int)
    case numberLineEndpoints(start: Int, end: Int)
    case numberLine(start: Int, middle: Int, end: Int, firstJump: Int, secondJump: Int)
    case nearTen(value: Int, neighbor: Int)
    case tenAdjustment(start: Int, intermediate: Int, result: Int)
}

private struct StrategyLessonStep: Identifiable, Equatable {
    let id = UUID()
    let prompt: String
    let explanation: String
    let equationTrail: [String]
    let highlightedElements: [String]
    let visual: StrategyLessonVisual
    let choices: [String]
    let correctChoice: String?
}

private struct StrategyLesson {
    let title: String
    let rule: String
    let iconName: String
    let steps: [StrategyLessonStep]
}

private enum StrategyLessonFactory {
    static func lesson(for mission: SpecialMissionID, language: AppLanguage) -> StrategyLesson {
        let de = language == .german

        switch mission {
        case .friendsOf10:
            return StrategyLesson(
                title: de ? "Freunde der 10" : "Friends of 10",
                rule: de ? "Zwei Zahlen sind Freunde, wenn sie zusammen 10 ergeben." : "Two numbers are friends when they make 10 together.",
                iconName: "10.circle.fill",
                steps: [
                    step(de ? "Sieh die Lücke" : "See the gap", de ? "Acht Plätze sind voll. Schau auf die leeren Plätze." : "Eight spaces are full. Look at the empty spaces.", ["8 + ? = 10"], ["8"], .tenFrame(left: 8, right: 0, moved: 0)),
                    step(de ? "Wie viele fehlen?" : "How many are missing?", de ? "Wähle die Zahl, die das Zehnerfeld füllt." : "Choose the number that fills the ten-frame.", ["8 + ? = 10"], ["?"], .tenFrame(left: 8, right: 0, moved: 0), choices: ["1", "2", "3"], correctChoice: "2"),
                    step(de ? "Nutze den Freund" : "Use the friend", de ? "Die 2 füllt die Lücke: 8 und 2 ergeben 10." : "The 2 fills the gap: 8 and 2 make 10.", ["8 + ? = 10", "8 + 2 = 10", "7 + 3 = 10"], ["2", "10"], .tenFrame(left: 10, right: 0, moved: 2))
                ]
            )
        case .bridgingThrough10:
            return StrategyLesson(
                title: de ? "Über die 10" : "Bridge through 10",
                rule: de ? "Mach zuerst die 10. Addiere danach den Rest." : "Make 10 first. Then add what is left.",
                iconName: "arrow.triangle.turn.up.right.circle.fill",
                steps: [
                    step(de ? "Sieh die Aufgabe" : "See the problem", de ? "Der 8 fehlen zwei Punkte bis zur 10." : "The 8 needs two dots to reach 10.", ["8 + 5"], ["8", "5"], .tenFrame(left: 8, right: 5, moved: 0)),
                    step(de ? "Teile die 5 passend" : "Split the 5", de ? "Welche Aufteilung gibt der 8 genau zwei Punkte?" : "Which split gives the 8 exactly two dots?", ["8 + 5", "5 = ? + ?"], ["5"], .tenFrame(left: 8, right: 5, moved: 0), choices: ["1 + 4", "2 + 3", "3 + 2"], correctChoice: "2 + 3"),
                    step(de ? "Mach 10, dann den Rest" : "Make 10, then add the rest", de ? "Zwei Punkte wandern zur 8; drei bleiben übrig." : "Two dots move to the 8; three remain.", ["8 + 5", "8 + 2 + 3", "10 + 3", "13"], ["2", "10", "13"], .tenFrame(left: 10, right: 3, moved: 0))
                ]
            )
        case .doublesNearDoubles:
            return StrategyLesson(
                title: de ? "Zwillinge" : "Use a double",
                rule: de ? "Finde den richtigen Zwilling. Addiere dann den Extra-Punkt." : "Find the double you know. Then add the extra dot.",
                iconName: "equal.circle.fill",
                steps: [
                    step(de ? "Paare die Punkte" : "Pair the dots", de ? "Sieben Punkte haben einen Partner. Einer bleibt allein." : "Seven dots have a partner. One dot is left alone.", ["7 + 8"], ["7", "8"], .dotRows(top: 7, bottom: 8, extra: 1)),
                    step(de ? "Welcher Zwilling steckt darin?" : "Which double is inside?", de ? "Was ist der richtige Zwilling?" : "Choose the right double without the extra dot.", ["7 + 8 = ? + 1"], ["+ 1"], .dotRows(top: 7, bottom: 8, extra: 1), choices: ["6 + 6", "7 + 7", "8 + 8"], correctChoice: "7 + 7"),
                    step(de ? "Addiere den Extra-Punkt" : "Add the extra dot", de ? "7 + 7 ergibt 14; plus der einzelne Punkt macht 15." : "7 + 7 makes 14; adding the lone dot makes 15.", ["7 + 8", "7 + 7 + 1", "14 + 1", "15"], ["7 + 7", "1", "15"], .dotRows(top: 7, bottom: 8, extra: 1))
                ]
            )
        case .countingUp:
            return StrategyLesson(
                title: de ? "Hochzählen" : "Count up",
                rule: de ? "Starte bei der kleineren Zahl. Die Sprünge bis zur größeren Zahl sind die Antwort." : "Start at the smaller number. The jumps to the larger number are the answer.",
                iconName: "arrow.up.forward.circle.fill",
                steps: [
                    step(de ? "Sieh den Abstand" : "See the distance", de ? "13 − 8 bedeutet: Wie weit ist es von 8 bis 13?" : "13 − 8 means: How far is it from 8 to 13?", ["13 − 8 = ?"], ["8", "13"], .numberLineEndpoints(start: 8, end: 13)),
                    step(de ? "Wähle den leichten Zwischenstopp" : "Choose the easy stop", de ? "Zu welcher Zahl kommst Du besonders leicht?" : "Which number makes the first jump especially easy?", ["8 → ? → 13"], ["?"], .numberLineEndpoints(start: 8, end: 13), choices: ["9", "10", "11"], correctChoice: "10"),
                    step(de ? "Addiere die Sprünge" : "Add the jumps", de ? "Von 8 bis 10 sind es 2, dann noch 3 bis 13." : "It is 2 from 8 to 10, then 3 more to 13.", ["13 − 8", "8 → 10: +2", "10 → 13: +3", "2 + 3 = 5"], ["2", "3", "5"], .numberLine(start: 8, middle: 10, end: 13, firstJump: 2, secondJump: 3))
                ]
            )
        case .nineTrick:
            return StrategyLesson(
                title: "9-Trick",
                rule: de ? "9 ist 10 minus 1. Rechne mit 10 und korrigiere danach um 1." : "Nine is 10 minus 1. Use 10, then correct by 1.",
                iconName: "9.circle.fill",
                steps: [
                    step(de ? "Sieh die Nähe zur 10" : "See how close 9 is to 10", de ? "9 ist nur eins kleiner als 10." : "Nine is only one less than 10.", ["24 + 9"], ["9"], .nearTen(value: 9, neighbor: 10)),
                    step(de ? "Wie ersetzen wir +9?" : "How can we replace +9?", de ? "Wandle die Aufgabe mit dem richtigen 9er Trick um." : "Choose the same change in an easier form.", ["24 + 9 = 24 + ?"], ["9"], .nearTen(value: 9, neighbor: 10), choices: ["10 + 1", "10 − 1", "9 − 1"], correctChoice: "10 − 1"),
                    step(de ? "Korrigiere um eins" : "Correct by one", de ? "Addiere 10 und gehe danach einen Schritt zurück." : "Add 10, then take one step back.", ["24 + 9", "24 + 10 − 1", "34 − 1", "33"], ["10", "− 1", "33"], .tenAdjustment(start: 24, intermediate: 34, result: 33))
                ]
            )
        }
    }

    private static func step(_ prompt: String, _ explanation: String, _ equationTrail: [String], _ highlightedElements: [String], _ visual: StrategyLessonVisual, choices: [String] = [], correctChoice: String? = nil) -> StrategyLessonStep {
        StrategyLessonStep(prompt: prompt, explanation: explanation, equationTrail: equationTrail, highlightedElements: highlightedElements, visual: visual, choices: choices, correctChoice: correctChoice)
    }
}

struct StrategyIntroAnimationView: View {
    let mission: SpecialMissionID
    let language: AppLanguage
    let accessibilityOptions: GameAccessibilityOptions
    let onComplete: () -> Void

    @State private var stepIndex = 0
    @State private var completed = false
    @State private var selectedChoice: String?

    private var lesson: StrategyLesson {
        StrategyLessonFactory.lesson(for: mission, language: language)
    }

    private var step: StrategyLessonStep {
        lesson.steps[min(stepIndex, lesson.steps.count - 1)]
    }

    private var isLastStep: Bool { stepIndex == lesson.steps.count - 1 }
    private var canContinue: Bool { step.correctChoice == nil || selectedChoice == step.correctChoice }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.indigo.opacity(0.98), Color.black.opacity(0.96)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: lesson.iconName)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color.yellow, Color.orange)
                    Text(lesson.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(language == .german ? "Überspringen" : "Skip") { finish() }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 6) {
                    ForEach(lesson.steps.indices, id: \.self) { index in
                        Capsule().fill(index <= stepIndex ? Color.yellow : Color.white.opacity(0.22)).frame(height: 6)
                    }
                }

                StrategyLessonCard(
                    step: step,
                    language: language,
                    accessibilityOptions: accessibilityOptions,
                    selectedChoice: selectedChoice,
                    onSelectChoice: { selectedChoice = $0 }
                )
                .id(step.id)
                .transition(accessibilityOptions.reduceMotionEffects ? .opacity : .scale.combined(with: .opacity))

                if isLastStep {
                    Label(lesson.rule, systemImage: "lightbulb.fill")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                HStack(spacing: 12) {
                    Button { withAnimation { stepIndex = max(0, stepIndex - 1); selectedChoice = nil } } label: {
                        Label(language == .german ? "Zurück" : "Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered).tint(.white).disabled(stepIndex == 0)

                    Button {
                        if isLastStep { finish() } else { withAnimation { stepIndex += 1; selectedChoice = nil } }
                    } label: {
                        Label(isLastStep ? (language == .german ? "Mission starten" : "Start mission") : (language == .german ? "Weiter" : "Next"), systemImage: isLastStep ? "play.fill" : "chevron.right")
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(!canContinue)

                    if isLastStep {
                        Button { withAnimation { stepIndex = 0; selectedChoice = nil } } label: {
                            Label(language == .german ? "Nochmal zeigen" : "Show again", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered).tint(.cyan)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .onAppear { stepIndex = 0; selectedChoice = nil }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lesson.title)
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        onComplete()
    }
}

private struct StrategyLessonCard: View {
    let step: StrategyLessonStep
    let language: AppLanguage
    let accessibilityOptions: GameAccessibilityOptions
    let selectedChoice: String?
    let onSelectChoice: (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(step.explanation).font(.title2.weight(.bold)).foregroundColor(.white).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            StrategyLessonVisualView(visual: step.visual).frame(minHeight: 130)
            EquationTrailView(equations: step.equationTrail, highlightedElements: step.highlightedElements, reduceMotion: accessibilityOptions.reduceMotionEffects)

            if !step.choices.isEmpty {
                HStack(spacing: 10) {
                    ForEach(step.choices, id: \.self) { choice in
                        Button(choice) { onSelectChoice(choice) }
                            .font(.title3.weight(.black))
                            .buttonStyle(.borderedProminent)
                            .tint(choiceColor(choice))
                    }
                }
                if let selectedChoice, selectedChoice != step.correctChoice {
                    Text(language == .german ? "Schau noch einmal auf das Bild." : "Look at the picture once more.")
                        .font(.subheadline.weight(.bold)).foregroundColor(.orange)
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.vertical, 20).padding(.horizontal, 18)
        .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.24), lineWidth: 1))
    }

    private func choiceColor(_ choice: String) -> Color {
        guard selectedChoice == choice else { return .blue }
        return choice == step.correctChoice ? .green : .orange
    }
}

private struct EquationTrailView: View {
    let equations: [String]
    let highlightedElements: [String]
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 5) {
            ForEach(Array(equations.enumerated()), id: \.offset) { index, equation in
                StrategyExpressionView(
                    expression: equation,
                    highlightedElements: index == equations.count - 1 ? highlightedElements : [],
                    movingElements: [],
                    reduceMotion: reduceMotion
                )
                .scaleEffect(index == equations.count - 1 ? 1 : 0.78)
                .opacity(index == equations.count - 1 ? 1 : 0.42)
            }
        }
    }
}

private struct StrategyLessonVisualView: View {
    let visual: StrategyLessonVisual

    var body: some View {
        switch visual {
        case let .tenFrame(left, right, moved):
            HStack(spacing: 24) {
                TenFrameView(filled: left, accentCount: moved)
                if right > 0 {
                    Image(systemName: moved > 0 ? "arrow.left" : "plus").font(.title.weight(.black)).foregroundColor(.cyan)
                    DotGroupView(count: right, accentCount: moved, baseColor: left == 10 ? .yellow : .orange)
                }
            }
        case let .dotRows(top, bottom, extra):
            VStack(alignment: .leading, spacing: 12) {
                DotRowView(count: top, extraCount: 0)
                DotRowView(count: bottom, extraCount: extra)
            }
        case let .numberLineEndpoints(start, end):
            HStack {
                NumberTile(value: start, color: .blue)
                Capsule().fill(Color.white.opacity(0.55)).frame(width: 170, height: 6)
                NumberTile(value: end, color: .orange)
            }
        case let .numberLine(start, middle, end, firstJump, secondJump):
            LessonNumberLineView(start: start, middle: middle, end: end, firstJump: firstJump, secondJump: secondJump)
        case let .nearTen(value, neighbor):
            HStack(spacing: 14) {
                NumberTile(value: value, color: .orange)
                Text("1").font(.title2.weight(.black)).foregroundColor(.cyan)
                Image(systemName: "arrow.right").foregroundColor(.cyan)
                NumberTile(value: neighbor, color: .green)
            }
        case let .tenAdjustment(start, intermediate, result):
            HStack(spacing: 10) {
                NumberTile(value: start, color: .blue)
                Image(systemName: "arrow.right")
                NumberTile(value: intermediate, color: intermediate == start ? .blue : .green)
                Image(systemName: "arrow.right")
                NumberTile(value: result, color: result == intermediate ? .green : .orange)
            }
            .font(.title2.weight(.black)).foregroundColor(.white)
        }
    }
}

private struct TenFrameView: View {
    let filled: Int
    let accentCount: Int
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 5), count: 5), spacing: 5) {
            ForEach(0..<10, id: \.self) { index in
                let isFilled = index < filled
                let isAccent = isFilled && index >= max(0, filled - accentCount)
                Circle().fill(isFilled ? (isAccent ? Color.cyan : Color.yellow) : Color.clear)
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2)).frame(width: 28, height: 28)
            }
        }
        .padding(8).background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DotGroupView: View {
    let count: Int
    let accentCount: Int
    let baseColor: Color
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 5), count: 3), spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Circle().fill(index < accentCount ? Color.cyan : baseColor).frame(width: 24, height: 24)
            }
        }.frame(maxWidth: 90)
    }
}

private struct DotRowView: View {
    let count: Int
    let extraCount: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Circle().fill(index >= count - extraCount ? Color.orange : Color.yellow).frame(width: 26, height: 26)
                    .overlay(index >= count - extraCount ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            }
        }
    }
}

private struct LessonNumberLineView: View {
    let start: Int
    let middle: Int
    let end: Int
    let firstJump: Int
    let secondJump: Int
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                jumpLabel(firstJump, color: .cyan)
                Spacer()
                jumpLabel(secondJump, color: .orange)
            }.padding(.horizontal, 38)
            ZStack {
                Capsule().fill(Color.white.opacity(0.55)).frame(height: 6)
                GeometryReader { geometry in
                    if firstJump > 0 {
                        jumpArc(from: geometry.size.width * 0.06, to: geometry.size.width * 0.50, color: .cyan)
                    }
                    if secondJump > 0 {
                        jumpArc(from: geometry.size.width * 0.50, to: geometry.size.width * 0.94, color: .orange)
                    }
                }
                .frame(height: 72)
                .offset(y: -36)
                HStack { marker(start); Spacer(); marker(middle); Spacer(); marker(end) }
            }
        }.frame(width: 330)
    }
    private func jumpArc(from: CGFloat, to: CGFloat, color: Color) -> some View {
        Path { path in
            path.move(to: CGPoint(x: from, y: 58))
            path.addQuadCurve(to: CGPoint(x: to, y: 58), control: CGPoint(x: (from + to) / 2, y: 2))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
    @ViewBuilder private func jumpLabel(_ value: Int, color: Color) -> some View {
        if value > 0 {
            Label("+\(value)", systemImage: "arrow.turn.up.right").font(.headline.weight(.black)).foregroundColor(color)
        } else { Color.clear.frame(height: 24) }
    }
    private func marker(_ value: Int) -> some View {
        Text("\(value)").font(.headline.weight(.black)).foregroundColor(.black).frame(width: 38, height: 38).background(Color.white, in: Circle())
    }
}

private struct NumberTile: View {
    let value: Int
    let color: Color
    var body: some View {
        Text("\(value)").font(.system(size: 30, weight: .black, design: .rounded)).foregroundColor(.white)
            .frame(width: 72, height: 62).background(color, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct StrategyStepView: View {
    let step: StrategyAnimationStep
    let accessibilityOptions: GameAccessibilityOptions

    var body: some View {
        VStack(spacing: 20) {
            StrategyExpressionView(
                expression: step.displayedExpression,
                highlightedElements: step.highlightedElements,
                movingElements: step.movingElements,
                reduceMotion: accessibilityOptions.reduceMotionEffects
            )

            if !step.arrows.isEmpty {
                HStack(spacing: 10) {
                    ForEach(step.arrows, id: \.self) { arrow in
                        Text(arrow)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                }
            }

            if !step.numberLineJumps.isEmpty {
                StrategyNumberLineView(jumps: step.numberLineJumps)
            }

            if let finalAnswer = step.optionalFinalAnswer {
                Text(finalAnswer)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange.opacity(accessibilityOptions.reduceMotionEffects ? 0 : 0.85), radius: 14)
            }
        }
        .frame(maxWidth: 560)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.22), lineWidth: 1))
    }
}

private struct StrategyExpressionView: View {
    let expression: String
    let highlightedElements: [String]
    let movingElements: [String]
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                let cleanToken = token.trimmingCharacters(in: .whitespaces)
                Text(token)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.55)
                    .foregroundColor(isHighlighted(cleanToken) ? .black : .white)
                    .padding(.horizontal, isHighlighted(cleanToken) ? 8 : 0)
                    .padding(.vertical, isHighlighted(cleanToken) ? 5 : 0)
                    .background(isHighlighted(cleanToken) ? Color.yellow : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .offset(y: movingElements.contains(cleanToken) && !reduceMotion ? -12 : 0)
                    .shadow(color: isHighlighted(cleanToken) ? .orange.opacity(0.8) : .clear, radius: reduceMotion ? 0 : 9)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.45)
        .padding(.horizontal, 8)
    }

    private var tokens: [String] {
        expression.split(separator: " ").map(String.init)
    }

    private func isHighlighted(_ token: String) -> Bool {
        highlightedElements.contains { highlighted in
            token == highlighted || token.contains(highlighted)
        }
    }
}

private struct StrategyNumberLineView: View {
    let jumps: [StrategyNumberLineJump]

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(height: 6)

            HStack {
                ForEach(jumps) { jump in
                    Text(jump.label)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .frame(maxWidth: .infinity)
                }
            }
            .offset(y: -28)

            HStack {
                Text("\(jumps.first?.from ?? 0)")
                Spacer()
                Text("\(jumps.last?.to ?? 0)")
            }
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .offset(y: 22)
        }
        .frame(width: 260, height: 56)
    }
}

struct ProjectileView: View {
    let projectile: Projectile
    let vehicleType: VehicleType
    let accessibilityOptions: GameAccessibilityOptions

    private var angle: Angle {
        Angle(radians: atan2(
            projectile.endPosition.y - projectile.startPosition.y,
            projectile.endPosition.x - projectile.startPosition.x
        ))
    }

    private var trailColor: Color {
        switch projectile.kind {
        case .playerShot:
            return .yellow
        case .enemyShot, .enemyDive:
            return .red
        }
    }

    private var coreColor: Color {
        switch projectile.kind {
        case .playerShot:
            return .white
        case .enemyShot, .enemyDive:
            return .orange
        }
    }

    var body: some View {
        ZStack {
            if projectile.kind == .playerShot, vehicleType == .unicorn {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(Color.yellow, Color.cyan)
                    .rotationEffect(angle + .degrees(90))
                    .shadow(color: Color.yellow.opacity(0.85), radius: accessibilityOptions.reduceMotionEffects ? 0 : 8)
                    .shadow(color: Color.cyan.opacity(0.55), radius: accessibilityOptions.reduceMotionEffects ? 0 : 12)
            } else if projectile.kind == .enemyDive, vehicleType == .unicorn, UIImage(named: "Witch") != nil {
                Image("Witch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 126)
                    .rotationEffect(angle + .degrees(90))
                    .shadow(color: trailColor.opacity(0.65), radius: accessibilityOptions.reduceMotionEffects ? 0 : 10)
            } else if projectile.kind == .enemyDive, UIImage(named: "Missile") != nil {
                Image("Missile")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 92, height: 122)
                    .frame(width: 64, height: 88)
                    .clipped()
                    .rotationEffect(angle + .degrees(90))
                    .shadow(color: trailColor.opacity(0.65), radius: accessibilityOptions.reduceMotionEffects ? 0 : 10)
            } else {
                Capsule()
                    .fill(trailColor.opacity(0.45))
                    .frame(width: 34, height: 8)
                    .rotationEffect(angle)

                Circle()
                    .fill(coreColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: trailColor.opacity(0.8), radius: 10)
            }
        }
        .position(projectile.currentPosition)
        .accessibilityHidden(true)
    }
}

struct LifeBarHUD: View {
    let language: AppLanguage
    let remainingLives: Int
    let maximumLives: Int
    let vehicleType: VehicleType

    private var activeColor: Color {
        if remainingLives <= 3 {
            return .red
        }

        switch vehicleType {
        case .jet:
            return .green
        case .tank:
            return .yellow
        case .unicorn:
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(AppCopy(language: language).lives(remainingLives))
                .font(.caption.weight(.bold))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                ForEach(0..<maximumLives, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < remainingLives ? activeColor : Color.white.opacity(0.18))
                        .frame(width: 16, height: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy(language: language).lives(remainingLives))
    }
}

struct VehicleView: View {
    let vehicleType: VehicleType

    private var vehicleFrame: CGSize {
        switch vehicleType {
        case .unicorn:
            return CGSize(width: 300, height: 180)
        case .jet, .tank:
            return CGSize(width: 150, height: 90)
        }
    }

    var body: some View {
        Group {
            switch vehicleType {
            case .jet:
                if UIImage(named: "Aircraft") != nil {
                    Image("Aircraft")
                        .resizable()
                        .scaledToFit()
                } else {
                    FallbackAircraftView()
                }

            case .tank:
                if UIImage(named: "Tank") != nil {
                    Image("Tank")
                        .resizable()
                        .scaledToFit()
                } else {
                    FallbackTankView()
                }

            case .unicorn:
                if UIImage(named: "Unicorn") != nil {
                    Image("Unicorn")
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "sparkles")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white, .pink)
                        .padding(10)
                }
            }
        }
        .frame(width: vehicleFrame.width, height: vehicleFrame.height)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }
}

private struct FallbackAircraftView: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.gray.opacity(0.95), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 88, height: 28)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 16)
                .offset(x: 16, y: -4)

            Capsule()
                .fill(Color.gray.opacity(0.82))
                .frame(width: 112, height: 10)
                .offset(y: 6)

            Triangle()
                .fill(Color.gray.opacity(0.8))
                .frame(width: 24, height: 20)
                .offset(x: -36, y: -2)

            Rectangle()
                .fill(Color.orange.opacity(0.9))
                .frame(width: 12, height: 5)
                .offset(x: -49)
                .blur(radius: 1.5)
        }
    }
}

private struct FallbackTankView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.26, green: 0.44, blue: 0.20), Color(red: 0.16, green: 0.28, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 98, height: 34)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.32, green: 0.50, blue: 0.24))
                .frame(width: 54, height: 24)
                .offset(x: -8, y: -16)

            Capsule()
                .fill(Color(red: 0.20, green: 0.30, blue: 0.15))
                .frame(width: 76, height: 10)
                .offset(y: 20)

            Rectangle()
                .fill(Color(red: 0.20, green: 0.30, blue: 0.15))
                .frame(width: 44, height: 6)
                .offset(x: 26, y: -14)
        }
    }
}
