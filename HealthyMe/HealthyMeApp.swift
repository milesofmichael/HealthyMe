//
//  HealthyMeApp.swift
//  HealthyMe
//
//  App entry point. Launches directly to the home screen.
//

import SwiftUI

@main
struct HealthyMeApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                .task(priority: .background) {
                    // Pre-warm WebKit processes at low priority so health
                    // fetching and AI work take precedence
                    WebKitWarmer.shared.warmUp()
                }
        }
    }
}
