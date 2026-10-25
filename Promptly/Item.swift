//
//  Item.swift
//  Promptly
//
//  Created by Aykut Güven on 25.10.26.
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
