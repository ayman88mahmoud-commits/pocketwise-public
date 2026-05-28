//
//  Item.swift
//  HouseholdBudget
//
//  Created by Ayman Mahmoud on 28/05/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
