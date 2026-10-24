# Math Pilot - iOS Math Game for Kids

A fun and educational iOS math game where kids play as a cartoon jet pilot shooting the correct answers to math problems.

## Features

- **Cartoon Jet Pilot Theme**: Kids control a jet pilot at the bottom of the screen
- **Math Problems**: Simple two-digit addition and subtraction problems
- **Flying Numbers**: Numbers fly toward the pilot from the top of the screen
- **Tap to Explode**: Correct answers explode with visual effects when tapped
- **Sound Effects**: Audio feedback for correct/incorrect answers and explosions
- **Progressive Difficulty**: Level increases as score improves
- **Score System**: Points for correct answers, no penalty for wrong ones

## How to Play

1. Tap "Start Game" to begin
2. Look at the math problem displayed at the top
3. Numbers will fly down from the top of the screen
4. Tap the correct answer to make it explode
5. Correct answers: +10 points × current level
6. Wrong answers: no point penalty, but cost a life during normal play
7. Missing the correct answer costs a life and gives one retry after a short delay
8. Game over happens when all lives are gone
9. Level up every 50 points

## Level Progression

| Time | Stage | Addition Examples | Subtraction Examples |
| --- | --- | --- | --- |
| 0:00-0:59 | Single Digit | `3 + 4 = ?` | `8 - 3 = ?` |
| 1:00-1:59 | Complements to 10 | `7 + ? = 10` | `10 - 6 = ?` |
| 2:00-2:59 | Crossing 10 | `8 + 5 = ?` | `14 - 7 = ?` |
| 3:00-3:59 | Complements to 20 | `13 + ? = 20` | `20 - 12 = ?` |
| 4:00-4:59 | Digit + Whole Tens | `7 + 20 = ?` | `27 - 7 = ?` |
| 5:00-5:59 | Double Digit + Single Digit No Crossing | `24 + 5 = ?` | `46 - 3 = ?` |
| 6:00-6:59 | Two Digit No Carry/Borrow | `23 + 14 = ?` | `54 - 23 = ?` |
| 7:00-7:59 | Two Digit With Carry/Borrow | `27 + 8 = ?` | `41 - 8 = ?` |
| 8:00-8:59 | Pattern: Tens Progression | `29 + 7 = ?`, `39 + 7 = ?`, `49 + 7 = ?` | `52 - 9 = ?`, `62 - 9 = ?`, `72 - 9 = ?` |
| 9:00-9:59 | Pattern: Ones Progression | `24 + 5 = ?`, `25 + 4 = ?` | `46 - 3 = ?`, `57 - 4 = ?` |
| 10:00+ | Mixed Advanced | Random mix of whole tens, no-crossing single-digit, two-digit, and pattern problems | Random mix of whole tens, no-crossing single-digit, two-digit, and pattern problems |

## Technical Details

- **Platform**: iOS 17.0+
- **Language**: Swift
- **Framework**: SwiftUI
- **Architecture**: MVVM with ObservableObject
- **Features**:
  - Real-time animation using Timer
  - Collision detection through tap gestures
  - Particle effects for explosions
  - Procedural sound generation

## Project Structure

```
MathPilot/
├── MathPilotApp.swift          # App entry point
├── ContentView.swift           # Main game UI
├── GameManager.swift           # Game logic and state management
├── GameViews.swift             # Flying number and explosion views
├── SoundManager.swift          # Sound effects
└── Assets.xcassets/           # App icons and assets
```

## Game Components

### GameManager
- Manages game state (score, level, game over)
- Generates math problems
- Spawns flying numbers
- Handles animations and collisions
- Controls game timers

### Views
- **JetPilotView**: Cartoon jet pilot character
- **FlyingNumberView**: Tappable numbers with color coding
- **ExplosionView**: Particle effect animations

### Sound Manager
- Procedurally generates sound effects
- No external audio files needed
- Different tones for correct/wrong answers

## Educational Value

- **Math Skills**: Practice addition and subtraction
- **Number Recognition**: Quick identification of correct answers
- **Hand-Eye Coordination**: Tapping moving targets
- **Decision Making**: Fast mental math under pressure

## Installation

1. Open `MathPilot.xcodeproj` in Xcode
2. Select your iOS device or simulator
3. Build and run the project

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later
- Swift 5.0 or later

## Future Enhancements

- Different difficulty levels
- More math operations (multiplication, division)
- Leaderboards and achievements
- Different jet pilot characters
- Background music
- More visual effects and animations
