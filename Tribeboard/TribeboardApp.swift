//
//  TribeboardApp.swift
//  Tribeboard
//
//  Created by Tafadzwa Mawere on 2026/02/03.
//

import SwiftUI
import CoreData

@main
struct TribeboardApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
