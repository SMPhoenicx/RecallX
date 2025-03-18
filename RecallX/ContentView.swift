//
//  ContentView.swift
//  RecallX
//
//  Created by Suman Muppavarapu on 3/9/25.
//

import SwiftUI
import Foundation
class SearchManager: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Recall] = []
    @Published var isSearching: Bool = false
    
    var allRecalls: [Recall] = []
    func getAllRecalls() -> [Recall] {
        return allRecalls
    }
    // Update the reference to all recalls
    func updateRecalls(_ recalls: [Recall]) {
        self.allRecalls = recalls
        if !searchText.isEmpty {
            performSearch()
        }
    }
    
    // Perform search with debounce
    func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Debounce implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            let results = self.filterRecalls(self.searchText)
            
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
    
    // Filter recalls based on search text
    private func filterRecalls(_ query: String) -> [Recall] {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Early return if query is empty
        if lowercasedQuery.isEmpty {
            return []
        }
        
        // First pass: exact title matches
        let exactMatches = allRecalls.filter { recall in
            guard let title = recall.Title?.lowercased() else { return false }
            return title.contains(lowercasedQuery)
        }
        
        // Second pass: related content matches (description, products)
        let relatedMatches = allRecalls.filter { recall in
            // Skip if it's already an exact match
            if exactMatches.contains(where: { $0.id == recall.id }) {
                return false
            }
            
            // Check description
            if let description = recall.Description?.lowercased(),
               description.contains(lowercasedQuery) {
                return true
            }
            
            // Check product names
            if recall.Products.contains(where: {
                $0.Name.lowercased().contains(lowercasedQuery) ||
                ($0.Description?.lowercased().contains(lowercasedQuery) ?? false)
            }) {
                return true
            }
            
            // Check hazards
            if recall.Hazards.contains(where: {
                $0.Name.lowercased().contains(lowercasedQuery)
            }) {
                return true
            }
            
            return false
        }
        
        // Third pass: fuzzy matching for misspellings
        let fuzzyMatches = allRecalls.filter { recall in
            // Skip if it's already matched
            if exactMatches.contains(where: { $0.id == recall.id }) ||
               relatedMatches.contains(where: { $0.id == recall.id }) {
                return false
            }
            
            // Apply fuzzy matching to title
            if let title = recall.Title {
                let fuzzyScore = calculateFuzzyScore(title, query: lowercasedQuery)
                if fuzzyScore > 0.7 { // Threshold for fuzzy match
                    return true
                }
            }
            
            return false
        }
        
        // Combine results with priority (exact matches first, then related, then fuzzy)
        return exactMatches + relatedMatches + fuzzyMatches
    }
    
    // Calculate fuzzy match score between two strings (0-1)
    private func calculateFuzzyScore(_ string: String, query: String) -> Double {
        let lowercasedString = string.lowercased()
        
        // Handle complete mismatch early
        if lowercasedString.isEmpty || query.isEmpty {
            return 0.0
        }
        
        // Levenshtein distance calculation
        let stringLength = lowercasedString.count
        let queryLength = query.count
        
        // Convert strings to arrays for easier character access
        let stringArray = Array(lowercasedString)
        let queryArray = Array(query)
        
        // Create matrix for dynamic programming
        var matrix = Array(repeating: Array(repeating: 0, count: queryLength + 1), count: stringLength + 1)
        
        // Initialize first row and column
        for i in 0...stringLength {
            matrix[i][0] = i
        }
        
        for j in 0...queryLength {
            matrix[0][j] = j
        }
        
        // Fill matrix
        for i in 1...stringLength {
            for j in 1...queryLength {
                if stringArray[i-1] == queryArray[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,      // deletion
                        matrix[i][j-1] + 1,      // insertion
                        matrix[i-1][j-1] + 1     // substitution
                    )
                }
            }
        }
        
        // Calculate similarity score (0-1)
        let distance = Double(matrix[stringLength][queryLength])
        let maxLength = Double(max(stringLength, queryLength))
        let similarity = 1.0 - (distance / maxLength)
        
        return similarity
    }
}

// MARK: - Recall Model Update - Add Equatable conformance
extension Recall: Equatable {
    static func == (lhs: Recall, rhs: Recall) -> Bool {
        // RecallID is the unique identifier, so comparing this is sufficient
        return lhs.RecallID == rhs.RecallID
    }
}
struct SearchResultsList: View {
    let recalls: [Recall]
    @EnvironmentObject var savedManager: SavedRecallsManager
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(recalls) { recall in
                    RecallPostView(recall: recall)
                }
            }
            .padding()
        }
    }
}
struct SearchBar: View {
    @Binding var searchText: String
    var isSearching: Bool
    var onCommit: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search recalls...", text: $searchText, onCommit: onCommit)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                if isSearching {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct RecallListView: View {
    @StateObject var viewModel = RecallViewModel()
    @StateObject private var searchManager = SearchManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(
                    searchText: $searchManager.searchText,
                    isSearching: searchManager.isSearching,
                    onCommit: {
                        searchManager.performSearch()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Content
                if !searchManager.searchText.isEmpty {
                    // Search results
                    if searchManager.searchResults.isEmpty {
                        if searchManager.isSearching {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(spacing: 20) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No results found for '\(searchManager.searchText)'")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        SearchResultsList(recalls: searchManager.searchResults)
                    }
                } else {
                    // Normal recalls list
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
                }
            }
            .navigationTitle("Recalls")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchRecalls() // Initial fetch
            }
            // Fix the onChange syntax - use .onChange for publisher
            .onReceive(viewModel.$recalls) { _ in
                searchManager.updateRecalls(viewModel.allRecalls)
            }
            .onChange(of: searchManager.searchText) { _ in
                searchManager.performSearch()
            }
        }
        .environmentObject(searchManager)
    }
}

// MARK: - MainTabView Update - Fix onChange syntax
struct MainTabView: View {
    
    @StateObject private var savedManager = SavedRecallsManager()
    @StateObject private var viewModel = RecallViewModel()
    @StateObject private var searchManager = SearchManager()
    @State private var showMenu: Bool = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $selectedTab) {
                    RecallListView()
                        .tag(0)
                    SavedRecallsView()
                        .tag(1)
                }
                SideMenu(isShowing: $showMenu, selectedTab: $selectedTab)
            }
            .toolbar(showMenu ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showMenu.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
        }
        .environmentObject(viewModel)
        .environmentObject(savedManager)
        .environmentObject(searchManager)
        .onAppear {
            viewModel.fetchRecalls() // Fetch recalls when the app appears
        }
        // Fix the onChange syntax - use .onReceive for publisher
        .onReceive(viewModel.$recalls) { _ in
            searchManager.updateRecalls(viewModel.allRecalls)
        }
    }
}
struct RecallPostView: View {
    let recall: Recall
    @State var showDetail: Bool = false
    @EnvironmentObject var savedManager: SavedRecallsManager

    var formattedDate: String {
        formatDate(from: recall.RecallDate ?? "")
    }
    
    var isSaved: Bool {
        savedManager.isRecallSaved(recall)
    }
    
    // Blue and green color scheme
    let primaryBlue = Color(red: 0.2, green: 0.5, blue: 0.8)
    let secondaryGreen = Color(red: 0.3, green: 0.7, blue: 0.4)

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
            Text(recall.Title ?? "No Title")
                .font(.headline)
                .lineLimit(2)

            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(.gray)

            // Description
            Text(recall.Description ?? "No Description")
                .font(.body)
                .lineLimit(3)

            // Buttons
            HStack {
                Button(action: {
                    withAnimation {
                        savedManager.toggleSaved(recall: recall)
                    }
                }) {
                    Label(isSaved ? "Saved" : "Save",
                          systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isSaved ? primaryBlue : .primary)
                        .animation(.easeInOut, value: isSaved)
                }

                Spacer()
                
                Button(action: {
                    showDetail.toggle()
                }) {
                    Text("View More")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryBlue, secondaryGreen]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(.horizontal)
        .sheet(isPresented: $showDetail) {
            RecallDetailView(recall: recall)
                .environmentObject(savedManager)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showDetail.toggle()
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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var savedManager: SavedRecallsManager
    
    // Colors
    let primaryBlue = Color(red: 0.2, green: 0.5, blue: 0.8)
    let secondaryGreen = Color(red: 0.3, green: 0.7, blue: 0.4)
    let lightBlue = Color(red: 0.85, green: 0.9, blue: 1.0)
    
    var isSaved: Bool {
        savedManager.isRecallSaved(recall)
    }
    
    var formattedDate: String {
        formatDate(from: recall.RecallDate ?? "")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Product Recall")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(recall.RecallNumber ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Images with pagination dots
                TabView {
                    ForEach(recall.Images) { image in
                        AsyncImage(url: URL(string: image.URL)) { phase in
                            if let img = phase.image {
                                img
                                    .resizable()
                                    .scaledToFill()
                            } else if phase.error != nil {
                                ZStack {
                                    Rectangle().foregroundColor(.gray.opacity(0.3))
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                }
                            } else {
                                ZStack {
                                    Rectangle().foregroundColor(.gray.opacity(0.1))
                                    ProgressView()
                                }
                            }
                        }
                        .overlay(
                            VStack {
                                Spacer()
                                if !image.Caption.isEmpty {
                                    Text(image.Caption)
                                        .font(.caption)
                                        .padding(8)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(8)
                                        .padding(.bottom)
                                }
                            }
                        )
                    }
                }
                .frame(height: 400)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Action buttons
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            savedManager.toggleSaved(recall: recall)
                        }
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .foregroundColor(isSaved ? primaryBlue : .gray)
                    }
                    
                    Button(action: {
                        // Share action
                        guard let recallURL = URL(string: recall.URL ?? "") else { return }
                        let shareSheet = UIActivityViewController(
                            activityItems: [recallURL],
                            applicationActivities: nil
                        )
                        
                        UIApplication.shared.windows.first?.rootViewController?.present(
                            shareSheet, animated: true, completion: nil
                        )
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Call to action button
                    if let recallURL = URL(string: recall.URL ?? "") {
                        Link(destination: recallURL) {
                            HStack {
                                Text("Official Information")
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(primaryBlue)
                            .cornerRadius(16)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Title and date section with gradient background
                VStack(alignment: .leading, spacing: 12) {
                    Text(recall.Title ?? "No Title")
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(formattedDate)
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.9))
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryBlue, secondaryGreen]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content sections
                Group {
                    // Description
                    contentSection(title: "Description", icon: "info.circle", color: primaryBlue) {
                        Text(recall.Description ?? "No description available")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Products
                    contentSection(title: "Products", icon: "tag", color: secondaryGreen) {
                        ForEach(recall.Products, id: \.id) { product in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.Name)
                                    .font(.headline)
                                    .foregroundColor(primaryBlue)
                                
                                if let model = product.Model, !model.isEmpty {
                                    Text("Model: \(model)")
                                        .font(.subheadline)
                                }
                                
                                if let description = product.Description, !description.isEmpty {
                                    Text(description)
                                        .font(.body)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            if product.id != recall.Products.last?.id {
                                Divider()
                            }
                        }
                    }
                    
                    // Hazards
                    contentSection(title: "Hazards", icon: "exclamationmark.triangle", color: .red) {
                        ForEach(recall.Hazards, id: \.id) { hazard in
                            Text("• \(hazard.Name)")
                                .padding(.vertical, 2)
                        }
                    }
                    
                    // Remedies
                    contentSection(title: "Remedies", icon: "checkmark.shield", color: secondaryGreen) {
                        ForEach(recall.Remedies, id: \.id) { remedy in
                            Text("• \(remedy.Name)")
                                .padding(.vertical, 2)
                        }
                    }
                    
                    // Manufacturers
                    if !recall.Manufacturers.isEmpty {
                        contentSection(title: "Manufacturers", icon: "building.2", color: primaryBlue) {
                            ForEach(recall.Manufacturers, id: \.id) { company in
                                Text("• \(company.Name)")
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    
                    // Contact information
                    if let contact = recall.ConsumerContact, !contact.isEmpty {
                        contentSection(title: "Contact Information", icon: "phone", color: primaryBlue) {
                            Text(contact)
                                .font(.body)
                        }
                    }
                }
                
                // Footer with external link
                VStack(spacing: 16) {
                    if let recallURL = URL(string: recall.URL ?? "") {
                        Link(destination: recallURL) {
                            HStack {
                                Text("View Full Recall Information")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.up.right.square")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [primaryBlue, secondaryGreen]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    
                    Text("RecallX • Stay Safe")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
        .edgesIgnoringSafeArea(.top)
        .background(lightBlue.ignoresSafeArea())
    }
    
    // Helper function to create consistent content sections
    @ViewBuilder
    func contentSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            content()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
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
#Preview{
    MainTabView()
}
