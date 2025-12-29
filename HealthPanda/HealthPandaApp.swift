//
//  HealthPandaApp.swift
//  HealthPanda
//
//  App entry point. Launches directly to the home screen.
//

import SwiftUI

@main
struct HealthPandaApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }
}
