//
//  ReaderWindowPreferences.swift
//  Promptly
//
//  Created by Aykut Güven on 26.10.26.
//

import Foundation

final class ReaderWindowPreferences {
    enum Failure: Error {
        case unreadable
        case encodingFailed
    }

    private let defaults: UserDefaults?
    private let key = "reader.windowPlacement.v1"

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func load() throws(Failure) -> ReaderWindowState {
        guard let data = defaults?.data(forKey: key) else { return ReaderWindowState() }
        do {
            return try JSONDecoder().decode(ReaderWindowState.self, from: data)
        } catch {
            throw .unreadable
        }
    }

    func save(_ state: ReaderWindowState) throws(Failure) {
        guard let defaults else { return }
        do {
            defaults.set(try JSONEncoder().encode(state), forKey: key)
        } catch {
            throw .encodingFailed
        }
    }
}
