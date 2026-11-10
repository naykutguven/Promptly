//
//  PrompterWindowLayoutConstants.swift
//  Promptly
//

import CoreGraphics

enum PrompterWindowLayoutConstants {
    // Preserve SwiftUI's existing scene identity across the feature rename.
    static let windowID = "prompter"
    static let defaultExpandedSize = CGSize(width: 640, height: 320)
    static let minimumExpandedSize = CGSize(width: 360, height: 200)
    static let collapsedHeight: CGFloat = 58
}
