//
//  Item.swift
//  apprehand
//
//  Created by jacopo on 30/07/24.
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
