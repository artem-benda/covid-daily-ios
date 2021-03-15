//
//  SummaryResponse.swift
//  CovidDaily
//
//  Created by Artem Benda on 14.03.2021.
//

import Foundation

struct SummaryResponse: Codable {
    let countries: [CountrySummaryDto]
    
    enum CodingKeys: String, CodingKey {
        case countries = "Countries"
    }
}
