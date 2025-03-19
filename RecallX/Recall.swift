//
//  Recall.swift
//  RecallX
//
//  Created by Suman Muppavarapu on 3/9/25.
//

import Foundation
import Combine

class RecallViewModel: ObservableObject {
    @Published var recalls: [Recall] = [] // Displayed recalls
    @Published var allRecalls: [Recall] = [] // Full dataset
    private let batchSize = 25 // Number of recalls per page
    private let maxRecalls = 200 // Limit number of recalls
    private var currentIndex = 0 // Tracks loaded items
    
    func fetchRecalls() {
        guard allRecalls.isEmpty else { return } // Avoid duplicate fetches
        
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let formattedRecentDate = dateFormatter.string(from: oneWeekAgo!)
        let formattedBrandDate = dateFormatter.string(from: threeMonthsAgo!)
        
        guard let url = URL(string: "http://www.saferproducts.gov/RestWebServices/Recall?format=Json&LastPublishDateStart=\(formattedBrandDate)") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching recalls: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                var recalls = try decoder.decode([Recall].self, from: data)
                
                let popularBrands = [
                    "Apple", "Samsung", "Tesla", "Toyota", "Sony", "LG", "Honda", "Ford", "Chevrolet", "BMW", "Nike", "Adidas", "Under Armour", "North Face", "Patagonia",
                    "Hydro Flask", "Yeti", "Stanley", "PepsiCo", "Coca-Cola", "Frito-Lay", "Nestlé", "Procter & Gamble", "Johnson & Johnson", "Unilever", "Colgate-Palmolive",
                    "Keurig Dr Pepper", "General Mills", "Kellogg's", "Mondelez", "Mars", "Clorox", "3M", "Dyson", "Whirlpool", "KitchenAid", "Black+Decker", "DeWalt", "Makita",
                    "Energizer", "Duracell", "HP", "Dell", "Lenovo", "Microsoft", "Google", "Amazon", "Nintendo", "PlayStation", "Xbox"
                ]
                
                // Get brand recalls first
                var brandRecalls = recalls.filter { recall in
                    recall.Manufacturers.contains { popularBrands.contains($0.Name) }
                }
                
                // Get recent recalls
                let recentRecalls = recalls.filter { recall in
                    if let dateStr = recall.LastPublishDate, let date = dateFormatter.date(from: dateStr) {
                        return date >= oneWeekAgo!
                    }
                    return false
                }
                
                // Filter relevant product types AFTER brand/recent filtering
                let relevantTypes = ["Electronics", "Automobile", "Household", "Toys", "Food", "Appliances", "Outdoor Equipment", "Sports", "Furniture", "Clothing", "Baby Products", "Health & Beauty"]
                brandRecalls = brandRecalls.filter { recall in
                    recall.Products.contains { product in
                        if let type = product.Types {
                            return relevantTypes.contains(where: { type.localizedCaseInsensitiveContains($0) })
                        }
                        return false
                    }
                }
                
                // Merge both lists, ensuring we get at least some recalls
                var finalRecalls = Array((recentRecalls + brandRecalls).prefix(self.maxRecalls))
                if finalRecalls.isEmpty {
                    finalRecalls = Array(recalls.prefix(self.maxRecalls)) // Fallback to some data
                }
                
                DispatchQueue.main.async {
                    self.allRecalls = finalRecalls
                    self.loadMoreRecalls() // Load first batch
                }
            } catch {
                print("Error decoding recalls: \(error)")
            }
        }.resume()
    }
    
    func loadMoreRecalls() {
        let nextIndex = min(currentIndex + batchSize, allRecalls.count)
        if currentIndex < nextIndex {
            recalls.append(contentsOf: allRecalls[currentIndex..<nextIndex])
            currentIndex = nextIndex
        }
    }
}




struct Recall: Codable, Identifiable {
    // Use RecallID as the unique id.
    var id: Int { RecallID }
    let RecallID: Int
    let RecallNumber: String?
    let RecallDate: String?
    let Description: String?
    let URL: String?
    let Title: String?
    // Make ConsumerContact optional to allow for null values.
    let ConsumerContact: String?
    let LastPublishDate: String?
    let Products: [Product]
    let Inconjunctions: [Inconjunction]
    let Images: [RecallImage]
    let Injuries: [Injury]
    let Manufacturers: [Company]
    let Retailers: [Company]
    let Importers: [Company]
    let Distributors: [Company]?
    let SoldAtLabel: String?
    let ManufacturerCountries: [Country]
    let ProductUPCs: [ProductUPC]?
    let Hazards: [Hazard]
    let Remedies: [Remedy]
    let RemedyOptions: [RemedyOption]
}


struct Product: Codable, Identifiable {
    // This property is not part of the JSON so exclude it from decoding.
    var id = UUID()
    let Name: String
    let Description: String?
    let Model: String?
    let Types: String?
    let CategoryID: String?
    let NumberOfUnits: String?
    
    enum CodingKeys: String, CodingKey {
        case Name, Description, Model, Types, CategoryID, NumberOfUnits
    }
}

struct Inconjunction: Codable, Identifiable {
    var id = UUID()
    let URL: String
    
    enum CodingKeys: String, CodingKey {
        case URL
    }
}

struct RecallImage: Codable, Identifiable {
    let URL: String
    let Caption: String
    // Use the URL as a unique identifier.
    var id: String { URL }
}

struct Injury: Codable, Identifiable {
    var id = UUID()
    let Name: String
    
    enum CodingKeys: String, CodingKey {
        case Name
    }
}

struct Company: Codable, Identifiable {
    let Name: String
    let CompanyID: String?
    // Use the Name as a unique identifier.
    var id: String { Name }
}

struct Country: Codable, Identifiable {
    let Country: String
    var id: String { Country }
}

struct Hazard: Codable, Identifiable {
    let Name: String
    let HazardType: String?
    let HazardTypeID: String?
    var id: String { Name }
}

struct Remedy: Codable, Identifiable {
    let Name: String
    var id: String { Name }
}

struct RemedyOption: Codable, Identifiable {
    let Option: String
    var id: String { Option }
}

/// Custom type to decode ProductUPCs that might be either a String or a Dictionary.
enum ProductUPC: Codable, Identifiable {
    case string(String)
    case dictionary([String: String])
    
    var id: String {
        switch self {
        case .string(let value):
            return value
        case .dictionary(let dict):
            // Join dictionary values to create a unique id.
            return dict.values.joined(separator: "-")
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // First try to decode as a string.
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }
        // Then try to decode as a dictionary.
        if let dictValue = try? container.decode([String: String].self) {
            self = .dictionary(dictValue)
            return
        }
        throw DecodingError.typeMismatch(ProductUPC.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Dictionary for ProductUPC"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .dictionary(let dict):
            try container.encode(dict)
        }
    }
}
