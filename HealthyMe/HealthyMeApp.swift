//
//  HealthyMeApp.swift
//  HealthyMe
//
//  App entry point. Creates the AppSession and injects it into the environment.
//  All views access health services through the session, which vends the
//  appropriate implementation based on the current mode (standard or demo).
//

import SwiftUI

@main
struct HealthyMeApp: App {
    /// App session manages mode (standard/demo) and vends appropriate services
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(session)
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
                .task(priority: .background) {
                    // Pre-warm WebKit processes at low priority so health
                    // fetching and AI work take precedence
                    WebKitWarmer.shared.warmUp()
                }
        }
    }
}
