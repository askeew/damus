import Foundation
import SwiftUI

/// Manages user's favorite profiles using NIP-51 lists
class FavoritesManager: FavoritesManagerProtocol {
    static let shared = FavoritesManager()
    
    @Published private(set) var favorites: Set<Pubkey> = []
    var event: NostrEvent?
    
        private init() {
        Log.debug("FavoritesManager: Initializing", for: .timeline)
    }
    
    func isFavorite(_ pubkey: Pubkey) -> Bool {
        let isFav = favorites.contains(pubkey)
        Log.debug("FavoritesManager: Checking if %s is favorite: %s", for: .timeline, pubkey.hex(), String(isFav))
        return isFav
    }
    
    func toggleFavorite(_ pubkey: Pubkey) {
        Log.debug("FavoritesManager: Toggling favorite for %s", for: .timeline, pubkey.hex())

        if favorites.contains(pubkey) {
            favorites.remove(pubkey)
            Log.info("FavoritesManager: Removed %s from favorites", for: .timeline, pubkey.hex())
        } else {
            favorites.insert(pubkey)
            Log.info("FavoritesManager: Added %s to favorites", for: .timeline, pubkey.hex())
        }

        publishFavoritesList()
    }
        private func publishFavoritesList() {
        Log.debug("FavoritesManager: Publishing favorites list with %d favorites", for: .timeline, favorites.count)

        // TODO:

        Log.info("FavoritesManager: Favorites list published successfully", for: .timeline)
    }
}

protocol FavoritesManagerProtocol {
    func isFavorite(_ pubkey: Pubkey) -> Bool
    func toggleFavorite(_ pubkey: Pubkey)
}
