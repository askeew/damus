import Foundation
import SwiftUI

class FavoritesManagerMock: FavoritesManagerProtocol  {
    private var favorites: Set<Pubkey> = []
    
    func isFavorite(_ pubkey: Pubkey) -> Bool {
       favorites.contains(pubkey)
    }
    
    func toggleFavorite(_ pubkey: Pubkey) {
        if favorites.contains(pubkey) {
            favorites.remove(pubkey)
        } else {
            favorites.insert(pubkey)
        }
    }
}
