//
//  ContentView.swift
//  RecallX
//
//  Created by Suman Muppavarapu on 3/9/25.
//

import SwiftUI

struct RecallListView: View {
    @StateObject var viewModel = RecallViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.recalls) { recall in
                NavigationLink(destination: RecallDetailView(recall: recall)) {
                    VStack(alignment: .leading) {
                        Text(recall.Title)
                            .font(.headline)
                        Text("Date: \(recall.RecallDate)")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Recalls")
            .onAppear {
                viewModel.fetchRecalls()
            }
        }
    }
}


struct RecallDetailView: View {
    let recall: Recall
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recall.Title)
                    .font(.title)
                    .bold()
                Text("Recall Date: \(recall.RecallDate)")
                    .font(.subheadline)
                Text(recall.Description)
                    .font(.body)
                
                // Example: Displaying images in a horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(recall.Images) { image in
                            AsyncImage(url: URL(string: image.URL)) { phase in
                                if let img = phase.image {
                                    img
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 150)
                                } else if phase.error != nil {
                                    Color.red
                                        .frame(width: 150, height: 150)
                                } else {
                                    ProgressView()
                                        .frame(width: 150, height: 150)
                                }
                            }
                        }
                    }
                }
                
                // Link to more information
                if let recallURL = URL(string: recall.URL) {
                    Link("More Information", destination: recallURL)
                        .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
    }
}

#Preview{
    RecallListView()
}
