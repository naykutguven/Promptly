//
//  ReaderWindowPreferencesTests.swift
//  PromptlyTests
//
//  Created by Aykut Güven on 26.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Promptly

@MainActor
struct ReaderWindowPreferencesTests {
    @Test func isolatedPreferencesRoundTripAllPlacementState() throws {
        let suiteName = "PromptlyTests.ReaderWindowPreferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = ReaderWindowPreferences(defaults: defaults)
        #expect(try preferences.load() == ReaderWindowState())
        var state = ReaderWindowState()
        state.placement = .detached
        state.expansion = .collapsed
        state.positionLock = .locked
        state.expandedSize = CGSize(width: 700, height: 420)
        state.detachedFrame = CGRect(x: -1200, y: 200, width: 700, height: 420)
        state.displayID = 123

        try preferences.save(state)
        let reopened = ReaderWindowPreferences(defaults: defaults)
        #expect(try reopened.load() == state)
    }

    @Test func corruptPayloadReportsFailureWithoutDiscardingOriginalData() throws {
        let suiteName = "PromptlyTests.ReaderWindowPreferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "reader.windowPlacement.v1"
        let original = Data("invalid placement".utf8)
        defaults.set(original, forKey: key)
        let preferences = ReaderWindowPreferences(defaults: defaults)

        do {
            _ = try preferences.load()
            Issue.record("Corrupt placement should report an unreadable preference.")
        } catch {
            guard case .unreadable = error else {
                Issue.record("Unexpected placement preference failure.")
                return
            }
        }
        #expect(defaults.data(forKey: key) == original)
    }

    @Test func encodingFailurePreservesLastGoodPlacement() throws {
        let suiteName = "PromptlyTests.ReaderWindowPreferences.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "reader.windowPlacement.v1"
        let preferences = ReaderWindowPreferences(defaults: defaults)
        var saved = ReaderWindowState()
        saved.expandedSize = CGSize(width: 720, height: 400)
        try preferences.save(saved)
        let original = try #require(defaults.data(forKey: key))
        var invalid = saved
        invalid.expandedSize.width = .nan

        do {
            try preferences.save(invalid)
            Issue.record("A nonfinite placement size should fail to encode.")
        } catch {
            guard case .encodingFailed = error else {
                Issue.record("Unexpected placement preference failure.")
                return
            }
        }

        #expect(defaults.data(forKey: key) == original)
        #expect(try ReaderWindowPreferences(defaults: defaults).load() == saved)
    }
}
