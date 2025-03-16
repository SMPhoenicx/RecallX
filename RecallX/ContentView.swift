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
                ScrollView {
                    LazyVStack {
                        ForEach(viewModel.recalls) { recall in
                            RecallPostView(recall: recall)
                                .onAppear {
                                    if recall.id == viewModel.recalls.last?.id {
                                        viewModel.loadMoreRecalls() // Load more when last item appears
                                    }
                                }
                        }
                    }
                    .padding()
                }
            .navigationTitle("Recalls")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchRecalls() // Initial fetch
            }
        }
    }
}

struct MainTabView: View {
    
    @State private var showMenu: Bool = false
    @State private var selectedTab = 0
    var body: some View{
        NavigationStack{
            ZStack{
                TabView(selection: $selectedTab){
                    RecallListView()
                        .tag(0)
                    Text("SAVED")
                        .tag(1)
                }
                SideMenu(isShowing: $showMenu)
            }
            .toolbar(showMenu ? .hidden : .visible, for: .navigationBar)
            .toolbar{
                ToolbarItem(placement: .topBarLeading){
                    Button(action:{
                        showMenu.toggle()
                    }){
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
        }
    }
}

struct RecallPostView: View {
    let recall: Recall
    @State var showDetail: Bool = false

    var formattedDate: String {
        formatDate(from: recall.RecallDate!)
    }

    var body: some View {
        VStack(alignment: .leading) {
            // Horizontally scrolling images
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(recall.Images) { image in
                        AsyncImage(url: URL(string: image.URL)) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else if phase.error != nil {
                                Color.red
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 300, height: 200)
                        .clipped()
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.bottom, 5)

            // Title and Date
            Text(recall.Title!)
                .font(.headline)
                .lineLimit(2)

            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(.gray)

            // Description
            Text(recall.Description!)
                .font(.body)
                .lineLimit(3)

            // Buttons
            HStack {
                Button(action: {
                    // Save logic
                }) {
                    Label("Save", systemImage: "bookmark")
                }

                Spacer()
                Button(action:{
                    showDetail.toggle()
                }){
                    Text("View More")
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
        .sheet(isPresented: $showDetail){
            RecallDetailView(recall: recall)
        }
    }

    func formatDate(from isoString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: isoString) {
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        return isoString
    }
}

struct RecallDetailView: View {
    let recall: Recall
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(recall.Title!)
                    .font(.title)
                    .bold()
                Text("Recall Date: \(recall.RecallDate)")
                    .font(.subheadline)
                Text(recall.Description!)
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
                if let recallURL = URL(string: recall.URL!) {
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
    MainTabView()
}
