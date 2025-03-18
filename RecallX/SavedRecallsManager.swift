//
//  SavedRecallsManager.swift
//  RecallX
//
//  Created on 3/16/25.
//

import Foundation
import Combine

class SavedRecallsManager: ObservableObject {
    @Published var savedRecalls: [Int] = []
    
    private let saveKey = "savedRecalls"
    
    init() {
        loadSavedRecalls()
    }
    
    func loadSavedRecalls() {
        print("Loading saved recalls")
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            if let decoded = try? JSONDecoder().decode([Int].self, from: data) {
                DispatchQueue.main.async {
                    self.savedRecalls = decoded
                }
                print("Loaded saved recalls: \(decoded)")
                return
            }
        }
        
        print("No saved recalls found or error decoding")
        self.savedRecalls = []
    }
    
    func saveRecalls() {
        print("Saving recalls: \(savedRecalls)")
        if let encoded = try? JSONEncoder().encode(savedRecalls) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            UserDefaults.standard.synchronize() // Force immediate save
        }
    }
    
    func toggleSaved(recall: Recall) {
        print("Toggling saved status for recall ID: \(recall.RecallID)")
        if savedRecalls.contains(recall.RecallID) {
            savedRecalls.removeAll { $0 == recall.RecallID }
            print("Removed from saved")
        } else {
            savedRecalls.append(recall.RecallID)
            print("Added to saved")
        }
        saveRecalls()
    }
    
    func isRecallSaved(_ recall: Recall) -> Bool {
        return savedRecalls.contains(recall.RecallID)
    }
}
