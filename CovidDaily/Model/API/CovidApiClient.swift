//
//  CovidApiClient.swift
//  On the Map
//
//  Created by Artem Benda on 03.01.2021.
//

import Foundation

class CovidApiClient: ApiClient {
    
    enum Endpoint {
        private static let baseUrl = "https://api.covid19api.com"
        
        case getSummary
        case getDetailsByCountryAndState(slug: String, state: CovidCasesStatus)
        
        private var stringValue: String {
            switch self {
            case .getSummary:
                return Endpoint.baseUrl + "/summary"
            case .getDetailsByCountryAndState(let slug, let state):
                return Endpoint.baseUrl + "/total/country/\(slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")/status/\(state.rawValue.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")"
            }
        }
        
        var url: URL {
            get {
                return URL(string: self.stringValue)!
            }
        }
    }
    
    class func getSummary(completionHandler: @escaping ([CountrySummaryDto]?, Error?) -> Void) -> URLSessionTask {
        let task = taskForRequest(url: Endpoint.getSummary.url, httpMethod: .get, requestBody: nil as VoidRequestBody?, resultDataMapper: nil, resultType: SummaryResponse.self, errorResultType: VoidErrorResponseBody.self) { (result, error) in
            guard let result = result, error == nil else {
                completionHandler(nil, error)
                return
            }
            completionHandler(result.countries, nil)
        }
        task.resume()
        return task
    }
    
    class func getConfirmedDetailsByCountryAndState(slug: String, state: CovidCasesStatus, completionHandler: @escaping ([TotalByDateDto]?, Error?) -> Void) -> URLSessionTask {
        let task = taskForRequest(url: Endpoint.getDetailsByCountryAndState(slug: slug, state: state).url, httpMethod: .get, requestBody: nil as VoidRequestBody?, resultDataMapper: nil, resultType: [TotalByDateDto].self, errorResultType: VoidErrorResponseBody.self) { (result, error) in
            guard let result = result, error == nil else {
                completionHandler(nil, error)
                return
            }
            completionHandler(result, nil)
        }
        task.resume()
        return task
    }
    
    enum CovidCasesStatus: String {
        case confirmed, recovered, deaths
    }
}
