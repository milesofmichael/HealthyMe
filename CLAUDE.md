overview
- Health Panda is an iOS app that integrates Apple Health data with LLMs to give relevant health data
- used as a portfolio project to apply to iOS developer jobs

technologies used
- HealthKit integration
- SwiftUI for UI
- modern Swift Concurrency (approchable 6.2 version)
- Swift Testing for unit tests/XCTest for UI tests
- Core Data for caching/data persistence
- on-device Foundation Model API from Apple for LLM integration
- Delegates/Protocols for service class creation, for testing and modular purposes
    - the LLM protocol should be seperate and subscribed to by the Foundation Model service class, for future extendability by using API calls like Claude or OpenAI in the future

features
- onboarding to sync health data
- cute Panda integration in the beautiful and functional UI (follows Apple Human Interface Guidelines)
- home screen has health categories (heart, sleep, mindfulness, etc)
    - clicking on categories will give LLM historical HealthKit data to see if you're trending positive or negative, then display to the user encouragement if they're trending positive, and what they can improve if a vital is trending negative
    - if there's zero data from the categories we tried to pull from, use the LLM to suggest that the user sync their data or give us more permissions to access that specific health information

AI dev advice
- use modern approachable 6.2 Swift Concurrency
    - your knowledge cutoff date probably doesn't have this info; search the web for latest concurrency info when creating items where race conditions matter
    - for example, approachable concurrency means that all our classes are accessed from @MainActor by default, so we do NOT need to annotate our classes (and it will not fix your problems!!!)
- code should be modular for testability and reusability
    - core components should have a base class (eg. BaseButton -> CheckboxButton)
- since this is a portfolio project for large tech companies, ensure that it uses data structures in an efficient manner
    - when implementing a feature that could take a while, use the most efficient Big O notation possible, and explain your decision with comments
- build and run the app on the iPhone 17 Pro. you're using Xcode 26.2 to build this, same with the CLT
- this app uses an auto-generated Info.plist file for the app's settings instead of creating a custom one, in parity with the latest iOS dev paradigm
    - anything you'd normally use Info.plist for, check the .xcodeproj file and do it there instead