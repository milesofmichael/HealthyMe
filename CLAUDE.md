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
    - LLM code should be reusable just in case I want to add something like Claude API calls in the future
- Delegates/Protocols for service class creation, for testing and modular purposes
    - the LLM protocol should be seperate and subscribed to by the Foundation Model service class, for future extendability by using API calls like Claude or OpenAI in the future

fetching system design
- all data is fetched from single function in HealthFetcher when app is loaded
    - this same function should be attached to the refreshcontrol
- app should then go through each category in background tasks, check the cache update schedule, and call the foundation model if an update is needed (if foundation models not enabled, just do the simple update)
    - each update (monthly, daily, weekly) and each category should be a separate background async task
    - come back to the main thread only to update the UI when each task completes 
        - as each task individually completes, update the UI if it's a description on the home page, and update the CategoryDetailView if that category happens to be open at the time of update
- when the user opens the CategoryDetailView, one of 2 scenarios should happen:
    - they see the cached data that was stored in the cache or updated on app launch THEN stored in cache, OR
    - the data is still updating for that category, in which case, you update that data on the main thread for that category when it's done updating 
        - don't forget to update the cache too in this scenario


features
- cute Panda integration in the beautiful and functional UI (follows Apple Human Interface Guidelines)
- home screen has health categories (heart, sleep, mindfulness, etc)
- clicking on categories will give LLM historical HealthKit data to see if you're trending positive or negative for each metric, then display to the user encouragement if they're trending positive, and what they can improve if a vital is trending negative
- if there's zero data from the categories we tried to pull from, suggest that the user sync their data or give us more permissions to access that specific health information
- each category should use the cache if it's not worth updating the data
    - monthly = update once a week
    - weekly = update once every 3 days
    - daily = update daily

AI dev advice
- use modern approachable 6.2 Swift Concurrency
    - your knowledge cutoff date probably doesn't have this info; search the web for latest concurrency info when creating items where race conditions matter
    - for example, approachable concurrency means that all our classes are accessed from @MainActor by default, so we do NOT need to annotate our classes (and it will not fix your problems!!!)
- code should be modular for testability and reusability
    - core components should have a base class (eg. BaseButton -> CheckboxButton)
- since this is a portfolio project for large tech companies, ensure that it uses data structures in an efficient manner
    - when implementing a feature that could take a while, use the most efficient Big O notation possible, and explain your decision with comments
- this app uses an auto-generated Info.plist file for the app's settings instead of creating a custom one, in parity with the latest iOS dev paradigm
    - anything you'd normally use Info.plist for, check the .xcodeproj file and do it there instead
- any colors in the UI should come from (or be added to) Colors.swift
    - use Color Literal and Hex for color values