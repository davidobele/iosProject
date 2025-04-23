//
//  FavoritesManager.swift
//  Planter
//
//  Created on 4/20/25.
//

import Foundation

// Singleton class to manage favorites across the app
class FavoritesManager {
    static let shared = FavoritesManager()
    
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favoriteTeamPlayers"
    
    // Current list of favorite team players
    private(set) var favoriteTeamPlayers: [TeamPlayer] = []
    
    // Notification name for when favorites change
    static let favoritesChangedNotification = Notification.Name("FavoritesManagerFavoritesChanged")
    
    private init() {
        loadFavorites()
    }
    
    // Load favorites from persistent storage
    private func loadFavorites() {
        if let data = userDefaults.data(forKey: favoritesKey),
           let favorites = try? JSONDecoder().decode([TeamPlayer].self, from: data) {
            favoriteTeamPlayers = favorites
        }
    }
    
    // Save favorites to persistent storage
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteTeamPlayers) {
            userDefaults.set(data, forKey: favoritesKey)
        }
        
        // Notify observers that favorites have changed
        NotificationCenter.default.post(name: FavoritesManager.favoritesChangedNotification, object: nil)
    }
    
    // Toggle favorite status for a team player
    func toggleFavorite(teamPlayer: TeamPlayer) -> Bool {
        if let index = favoriteTeamPlayers.firstIndex(where: { $0.name == teamPlayer.name }) {
            // Remove from favorites
            favoriteTeamPlayers.remove(at: index)
            saveFavorites()
            return false
        } else {
            // Add to favorites
            var updatedTeamPlayer = teamPlayer
            updatedTeamPlayer.isFavorite = true
            favoriteTeamPlayers.append(updatedTeamPlayer)
            saveFavorites()
            return true
        }
    }
    
    // Check if a team player is favorited
    func isFavorite(teamPlayer: TeamPlayer) -> Bool {
        return favoriteTeamPlayers.contains(where: { $0.name == teamPlayer.name })
    }
    
    // Get all favorites
    func getAllFavorites() -> [TeamPlayer] {
        return favoriteTeamPlayers
    }
}
