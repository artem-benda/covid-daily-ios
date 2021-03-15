//
//  ApiClient.swift
//  On the Map
//
//  Created by Artem Benda on 05.01.2021.
//

import Foundation

class ApiClient {
    
    class func taskForRequest<RequestBodyType: Encodable, ResponseBodyType: Decodable, ErrorResultBodyType: Decodable & Error>(url: URL, httpMethod: HttpMethodType = .get, requestBody: RequestBodyType? = nil, resultDataMapper: ((Data?) -> Data?)?, resultType: ResponseBodyType.Type? = nil, errorResultType: ErrorResultBodyType.Type? = nil, completionHandler: @escaping (ResponseBodyType?, Error?) -> Void) -> URLSessionTask {
        print("Starting \(httpMethod.rawValue) request to URL: \(url.absoluteString)")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = httpMethod.stringValue
        if let requestBody = requestBody, httpMethod != .get {
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try! JSONEncoder().encode(requestBody)
        }
        let task = URLSession.shared.dataTask(with: urlRequest) { (data, urlResponse, error) in
            print("Request execution result: data = \(String(describing: String(data: data ?? Data(capacity: 0), encoding: .utf8))) urlResponse = \(String(describing: urlResponse)), error = \(String(describing: error))")
            // Error executing request
            guard error == nil else {
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            // Successfull, but no result needed
            guard let resultType = resultType, resultType != VoidResponseBody.self else {
                DispatchQueue.main.async {
                    completionHandler(nil, nil)
                }
                return
            }
            // Error, got empty result after mapping, while not empty result is needed
            guard let mappedData = resultDataMapper != nil ? resultDataMapper!(data) : data else {
                let error = NSError()
                DispatchQueue.main.async {
                    completionHandler(nil, error)
                }
                return
            }
            do {
                let jsonDecoder = JSONDecoder()
                jsonDecoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
                let resultObject = try jsonDecoder.decode(resultType.self, from: mappedData)
                // Successfully parsed result
                DispatchQueue.main.async {
                    completionHandler(resultObject, nil)
                }
                return
            } catch let error {
                guard let errorResultType = errorResultType, errorResultType != VoidErrorResponseBody.self else {
                    // Error result not set, returning error
                    DispatchQueue.main.async {
                        completionHandler(nil, error)
                    }
                    return
                }
                // Try to convert to ErrorResultBodyType
                do {
                    let jsonDecoder = JSONDecoder()
                    let resultObject = try jsonDecoder.decode(errorResultType.self, from: mappedData)
                    // Successfully parsed json for error type
                    DispatchQueue.main.async {
                        completionHandler(nil, resultObject)
                    }
                    return
                } catch let error {
                    // Error parsing error result
                    DispatchQueue.main.async {
                        completionHandler(nil, error)
                    }
                    return
                }
            }
        }
        return task
    }
}

enum HttpMethodType: String {
    case get
    case post
    case put
    case delete
    
    var stringValue: String {
        return self.rawValue.uppercased()
    }
}

struct VoidRequestBody: Encodable {}

struct VoidResponseBody: Decodable {}

struct VoidErrorResponseBody: Error, Decodable {}

extension DateFormatter {
  static let iso8601Full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}
