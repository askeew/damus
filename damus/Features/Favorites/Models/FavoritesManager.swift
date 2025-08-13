import Foundation
import SwiftUI

/// Manages user's favorite profiles using NIP-51 lists
class FavoritesManager: Favorites {
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
            notify(.unfavorite(pubkey))
            Log.info("FavoritesManager: Removed %s from favorites", for: .timeline, pubkey.hex())
        } else {
            favorites.insert(pubkey)
            notify(.favorite(pubkey))
            Log.info("FavoritesManager: Added %s to favorites", for: .timeline, pubkey.hex())
        }
    }

    func favorite_user_event(our_favorites: NostrEvent?, keypair: FullKeypair, favorite: Pubkey) -> NostrEvent? {
        guard let fs = our_favorites else {
            // Create a new favorites event if we don't have one
            return create_favorites_event(keypair: keypair, favorite: favorite)
        }
        guard let ev = favorite_with_existing_favorites(keypair: keypair, our_favorites: fs, favorite: favorite) else {
            return nil
        }
        return ev
    }

    func unfavorite_user_event(our_favorites: NostrEvent, keypair: FullKeypair, unfavorite: Pubkey) -> NostrEvent? {
        let tags = our_favorites.tags.reduce(into: [[String]]()) { ts, tag in
            if let tag = FollowRef.from_tag(tag: tag), tag == FollowRef.pubkey(unfavorite) {
                return
            }
            ts.append(tag.strings())
        }

        let kind = NostrKind.follow_list.rawValue

        return NostrEvent(content: our_favorites.content, keypair: keypair.to_keypair(), kind: kind, tags: Array(tags))
    }

    func create_favorites_event(keypair: FullKeypair, favorite: Pubkey) -> NostrEvent? {
        let kind = NostrKind.follow_list.rawValue
        let tags = [
            ["d", "favorites"],
            ["p", favorite.hex()]
        ]

        return NostrEvent(content: "", keypair: keypair.to_keypair(), kind: kind, tags: tags)
    }

    func favorite_with_existing_favorites(keypair: FullKeypair, our_favorites: NostrEvent, favorite: Pubkey) -> NostrEvent? {
        // don't update if we're already favoriting
        if is_already_favoriting(favorites: our_favorites, favorite: favorite) {
            return nil
        }

        let kind = NostrKind.follow_list.rawValue

        var tags = our_favorites.tags.strings()
        tags.append(["p", favorite.hex()])

        return NostrEvent(content: our_favorites.content, keypair: keypair.to_keypair(), kind: kind, tags: tags)
    }

    func is_already_favoriting(favorites: NostrEvent, favorite: Pubkey) -> Bool {
        return favorites.referenced_pubkeys.contains(favorite)
    }

    func favorite_reference(our_favorites: NostrEvent?, keypair: FullKeypair, favorite: Pubkey) -> NostrEvent? {
        return favorite_user_event(our_favorites: our_favorites, keypair: keypair, favorite: favorite)
    }

    func unfavorite_reference(our_favorites: NostrEvent?, keypair: FullKeypair, unfavorite: Pubkey) -> NostrEvent? {
        guard let fs = our_favorites else {
            return nil
        }
        return unfavorite_user_event(our_favorites: fs, keypair: keypair, unfavorite: unfavorite)
    }

    func handle_favorite_action(state: DamusState, target: Pubkey, is_favorite: Bool) {
        guard let keypair = state.keypair.to_full() else {
            return
        }

        let ev: NostrEvent?
        if is_favorite {
            ev = favorite_reference(our_favorites: event, keypair: keypair, favorite: target)
        } else {
            ev = unfavorite_reference(our_favorites: event, keypair: keypair, unfavorite: target)
        }

        guard let ev = ev else {
            return
        }

        state.nostrNetwork.postbox.send(ev)

        self.event = ev
    }

    func handle_favorite(state: DamusState, target: Pubkey) {
        handle_favorite_action(state: state, target: target, is_favorite: true)
    }

    func handle_unfavorite(state: DamusState, target: Pubkey) {
        handle_favorite_action(state: state, target: target, is_favorite: false)
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

protocol Favorites {
    func isFavorite(_ pubkey: Pubkey) -> Bool
    func toggleFavorite(_ pubkey: Pubkey)
    func handleEvent(_ ev: NostrEvent, pubkey: Pubkey)
    func handle_favorite(state: DamusState, target: Pubkey)
    func handle_unfavorite(state: DamusState, target: Pubkey)
    var event: NostrEvent? { get set }
}
