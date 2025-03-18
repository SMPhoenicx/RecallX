//
//  SavedRecallsView.swift
//  RecallX
//
//  Created on 3/16/25.
//

import SwiftUI

struct SavedRecallsView: View {
    @EnvironmentObject var viewModel: RecallViewModel
    @EnvironmentObject var savedManager: SavedRecallsManager
    
    var savedRecalls: [Recall] {
        // Debug output to see what's happening
        print("Total recalls: \(viewModel.recalls.count)")
        print("Saved recall IDs: \(savedManager.savedRecalls)")
        
        let filteredRecalls = viewModel.recalls.filter { recall in
            savedManager.savedRecalls.contains(recall.RecallID)
        }
        
        print("Filtered recalls count: \(filteredRecalls.count)")
        return filteredRecalls
    }
    
    var body: some View {
        NavigationView {
            Group {
                if savedRecalls.isEmpty {
                    VStack {
                        Image(systemName: "bookmark")
                            .font(.system(size: 72))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("No Saved Recalls")
                            .font(.title)
                            .foregroundColor(.gray)
                        
                        Text("Items you save will appear here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack {
                            ForEach(savedRecalls) { recall in
                                RecallPostView(recall: recall)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Saved Recalls")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Force refresh when view appears
                savedManager.loadSavedRecalls()
            }
        }
    }
}
