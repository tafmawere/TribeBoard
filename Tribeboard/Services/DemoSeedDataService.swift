//
//  DemoSeedDataService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/17.
//

import Foundation

/// Demo seed data service providing test user IDs. DEBUG-only; unused in Release.
enum DemoSeedDataService {
#if DEBUG
    static let rueId = "rue-demo-id"
    static let tafadzwaId = "tafadzwa-demo-id"
#endif
}
