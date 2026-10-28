# Release smoke checks

Requires Xcode and XcodeGen. Generate the isolated test project:

```sh
xcodegen generate --spec Tests/ReleaseSmoke/project.yml
xcodebuild test -project Tests/ReleaseSmoke/MathPilotReleaseSmoke.xcodeproj \
  -scheme ReleaseSmoke -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /private/tmp/MathPilotReleaseSmoke/DerivedData \
  -parallel-testing-enabled NO
```

Repeat on an iPad simulator. The test app uses `com.mathpilot.release-smoke`,
separate from the production app. Its test-only entry point seeds local history;
none of the fixture code is part of the shipping target.

The integration test runs five-task practice for all four operations, deliberately
answers one task incorrectly, verifies retries and duplicate taps, checks round
completion, and reloads stored history in a new manager. UI checks cover English
and German feedback, worked examples, launching practice, relaunch persistence,
and changing the language with empty history. Screenshot attachments are retained
in the Xcode test result bundle.

Mission coverage checks all eight strategies through the 14-question path (plus
two interactive helping steps), immediate three-choice availability, distinct
boss questions, three successful boss hits, duplicate taps, guided retries,
background-time exclusion, compact-screen repositioning, and reset during feedback.
The mission UI test checks that all choices are tappable and captures screenshots
of both the answer round and the persistent worked explanation.
