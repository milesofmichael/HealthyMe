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
        }
    }
}
