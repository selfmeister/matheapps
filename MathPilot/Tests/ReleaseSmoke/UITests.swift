import XCTest

final class ReleaseUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testEnglishFeedbackAndRelaunch() { checkFeedback(language: "english") }
    func testGermanFeedbackAndRelaunch() { checkFeedback(language: "german") }

    func testMissionChoicesAndReadableGuidedFeedback() {
        let app = XCUIApplication()
        app.launchEnvironment = ["SMOKE_LANGUAGE": "english"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        let missions = app.buttons["openMissions"]
        for _ in 0..<10 {
            if missions.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(missions.isHittable)
        missions.tap()
        let start = app.buttons["startMission-bridgingThrough10"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        if !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 10))
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.buttons["Answer 13"].waitForExistence(timeout: 3))
        let choices = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Answer "))
        XCTAssertEqual(choices.count, 3)
        for index in 0..<choices.count { XCTAssertTrue(choices.element(boundBy: index).isHittable) }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "mission-available-choices"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let wrong = choices.allElementsBoundByIndex.first { $0.label != "Answer 13" }!
        wrong.tap()
        XCTAssertTrue(app.buttons["continueMission"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "8 + 2 = 10")).firstMatch.exists)
        let feedback = XCTAttachment(screenshot: app.screenshot())
        feedback.name = "mission-worked-feedback"
        feedback.lifetime = .keepAlways
        add(feedback)
        app.buttons["continueMission"].tap()
        XCTAssertTrue(app.buttons["Answer 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["8 + ? = 10"].exists)
    }

    private func checkFeedback(language: String) {
        let german = language == "german"
        let app = XCUIApplication()
        app.launchEnvironment = ["SMOKE_LANGUAGE": language]
        app.launch()
        let feedback = app.buttons["openFeedback"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 15))
        feedback.tap()
        XCTAssertTrue(app.buttons["startFeedbackPractice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[german ? "Dein nächster Schritt" : "Your next step"].exists)
        XCTAssertTrue(app.staticTexts["8 + 5 = ?"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", german ? "Zerlege 5" : "split 5")).firstMatch.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "feedback-\(language)"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(feedback.waitForExistence(timeout: 15))
        feedback.tap()
        XCTAssertTrue(app.buttons["startFeedbackPractice"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[german ? "Dein nächster Schritt" : "Your next step"].exists)
        app.buttons["startFeedbackPractice"].tap()
        XCTAssertTrue(app.staticTexts[german ? "Übung: Aufgabe 1 von 5" : "Practice: problem 1 of 5"].waitForExistence(timeout: 10))
        let practice = XCTAttachment(screenshot: app.screenshot())
        practice.name = "practice-\(language)"
        practice.lifetime = .keepAlways
        add(practice)
    }

    func testEmptyFeedbackAndLanguageSwitch() {
        let app = XCUIApplication()
        app.launchEnvironment = ["SMOKE_LANGUAGE": "english", "SMOKE_EMPTY": "1"]
        app.launch()
        XCTAssertTrue(app.buttons["Deutsch"].waitForExistence(timeout: 15))
        app.buttons["Deutsch"].tap()
        app.buttons["openFeedback"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Löse mindestens 6 Aufgaben")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["startFeedbackPractice"].exists)
    }
}
