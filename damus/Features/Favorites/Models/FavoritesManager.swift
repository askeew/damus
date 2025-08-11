import Foundation
import SwiftUI

/// Manages user's favorite profiles using NIP-51 lists
class FavoritesManager: FavoritesManagerProtocol {
    static let shared = FavoritesManager()
    @Published private(set) var favorites: Set<Pubkey> = []
    var event: NostrEvent?

    private init() {}

    func isFavorite(_ pubkey: Pubkey) -> Bool {
        let isFav = favorites.contains(pubkey)
        Log.debug("FavoritesManager: Checking if %s is favorite: %s", for: .timeline, pubkey.hex(), String(isFav))
        return isFav
    }

    func toggleFavorite(_ pubkey: Pubkey) {
        if favorites.contains(pubkey) {
            favorites.remove(pubkey)
            Log.info("FavoritesManager: Removed %s from favorites", for: .timeline, pubkey.hex())
        } else {
            favorites.insert(pubkey)
            Log.info("FavoritesManager: Added %s to favorites", for: .timeline, pubkey.hex())
        }
    }

    func handleEvent(_ ev: NostrEvent, pubkey: Pubkey) {
        print(ev.debugDescription)
        guard let kind = ev.known_kind, kind == .follow_list else {
            return
        }
        // we only care about our lists
        guard ev.pubkey == pubkey else {
            return
        }
        // we only care about the most recent list
        guard let oldlist = event, ev.created_at > oldlist.created_at else {
            return
        }
        // Check if this is a favorites list
        guard ev.tags.contains(where: { tag in tag.count >= 2 && tag[0].string() == "d" && tag[1].string() == "favorites" }) else {
            return
        }

        self.event = ev

        let old = Set(oldlist.referenced_pubkeys)
        let new = Set(ev.referenced_pubkeys)
        let diffs = old.symmetricDifference(new)

        for diff in diffs {
            if new.contains(diff) {
                favorites.insert(diff)
            } else {
                favorites.remove(diff)
            }
        }

        Log.info("FavoritesManager: Updated favorites list from %d to %d", for: .timeline, old.count, new.count)
    }
}

protocol FavoritesManagerProtocol {
    func isFavorite(_ pubkey: Pubkey) -> Bool
    func toggleFavorite(_ pubkey: Pubkey)
    func handleEvent(_ ev: NostrEvent, pubkey: Pubkey)
    var event: NostrEvent? { get set }
}
