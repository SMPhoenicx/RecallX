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
    private var allRecalls: [Recall] = [] // Full dataset
    private let batchSize = 25 // Number of recalls per page
    private var currentIndex = 0 // Tracks loaded items

    func fetchRecalls() {
        guard allRecalls.isEmpty else { return } // Avoid duplicate fetches

        guard let url = URL(string: "http://www.saferproducts.gov/RestWebServices/Recall?format=Json") else {
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
                let recalls = try decoder.decode([Recall].self, from: data)

                DispatchQueue.main.async {
                    self.allRecalls = recalls
                    self.loadMoreRecalls() // Load first 25 recalls
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
