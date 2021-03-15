//
//  TotalByDateDto.swift
//  CovidDaily
//
//  Created by Artem Benda on 14.03.2021.
//

import Foundation

struct TotalByDateDto: Codable {
    let cases: Int
    let asOf: Date
    
    enum CodingKeys: String, CodingKey {
        case cases = "Cases"
        case asOf = "Date"
    }
}
