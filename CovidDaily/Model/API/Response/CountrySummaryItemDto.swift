//
//  CountrySummaryItemDto.swift
//  CovidDaily
//
//  Created by Artem Benda on 14.03.2021.
//

import Foundation

struct CountrySummaryDto: Codable {
    let countryName: String
    let countryCode: String
    let slug: String
    let newConfirmed: Int
    let totalConfirmed: Int
    let newDeaths: Int
    let totalDeaths: Int
    let newRecovered: Int
    let totalRecovered: Int
    let asOf: Date
    
    enum CodingKeys: String, CodingKey {
        case countryName = "Country"
        case countryCode = "CountryCode"
        case slug = "Slug"
        case newConfirmed = "NewConfirmed"
        case totalConfirmed = "TotalConfirmed"
        case newDeaths = "NewDeaths"
        case totalDeaths = "TotalDeaths"
        case newRecovered = "NewRecovered"
        case totalRecovered = "TotalRecovered"
        case asOf = "Date"
    }
}
