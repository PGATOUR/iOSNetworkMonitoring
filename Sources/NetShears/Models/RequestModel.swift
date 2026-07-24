//
//  RequestModel.swift
//  NetShears
//
//  Created by Mehdi Mirzaie on 6/9/21.
//
import Foundation
import UIKit

public final class NetShearsRequestModel: Codable {
    public let id: String
    public let url: String
    public let host: String?
    public let port: Int?
    public let scheme: String?
    public let date: Date
    public let method: String
    public let headers: [String: String]
    public var credentials: [String : String]
    public var cookies: String?
    public var httpBody: Data?
    public var code: Int
    public var responseHeaders: [String: String]?
    public var dataResponse: Data?
    public var errorClientDescription: String?
    public var duration: Double?
    public var isFinished: Bool
    public var responseSource: NetShearsResponseSource?
    
    init(request: NSURLRequest, session: URLSession?) {
        id = UUID().uuidString
        url = request.url?.absoluteString ?? ""
        host = request.url?.host
        port = request.url?.port
        scheme = request.url?.scheme
        date = Date()
        method = request.httpMethod ?? "GET"
        credentials = [:]
        var headers = request.allHTTPHeaderFields ?? [:]
        httpBody = request.httpBody
        code = 0
        isFinished = false
        
        
        // collect all HTTP Request headers except the "Cookie" header. Many request representations treat cookies with special parameters or structures. For cookie collection, refer to the bottom part of this method
        session?.configuration.httpAdditionalHeaders?
            .filter {  $0.0 != AnyHashable("Cookie") }
            .forEach { element in
                guard let key = element.0 as? String, let value = element.1 as? String else { return }
                headers[key] = value
        }
        self.headers = headers
        
        // if the target server uses HTTP Basic Authentication, collect username and password
        if let credentialStorage = session?.configuration.urlCredentialStorage,
            let host = self.host,
            let port = self.port {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: port,
                protocol: scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )

            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    guard let user = credential.user, let password = credential.password else { continue }
                    self.credentials[user] = password
                }
            }
        }
        
        //  collect cookies associated with the target host
        //  TODO: Add the else branch.
        /*  With the condition below, it is handled only the case where session.configuration.httpShouldSetCookies == true.
            Some developers could opt to handle cookie manually using the "Cookie" header stored in httpAdditionalHeaders
            and disabling the handling provided by URLSessionConfiguration (httpShouldSetCookies == false).
            See: https://developer.apple.com/documentation/foundation/nsurlsessionconfiguration/1411589-httpshouldsetcookies?language=objc
        */
        if let session = session, let url = request.url, session.configuration.httpShouldSetCookies {
            if let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty {
                self.cookies = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
            }
        }
    }
    
    func initResponse(response: URLResponse) {
        guard let responseHttp = response as? HTTPURLResponse else {return}
        code = responseHttp.statusCode
        responseHeaders = responseHttp.allHeaderFields as? [String: String]
    }
    
    init(url: String,
         host: String,
         method: String,
         requestObject: Data?,
         responseObject: Data?,
         success: Bool,
         statusCode: Int,
         duration: Double?,
         scheme: String,
         requestHeaders: [String: String]?,
         responseHeaders: [String: String]?,
         isFinished: Bool = true) {
        self.id = UUID().uuidString
        self.method = method
        self.scheme = scheme
        self.url = url
        self.host = host
        self.httpBody = requestObject
        self.code = statusCode
        self.responseHeaders = responseHeaders
        self.headers = requestHeaders ?? [:]
        self.dataResponse = responseObject
        self.date = Date()
        self.port = nil
        self.duration = duration
        self.credentials = [:]
        self.isFinished = isFinished
    }
    
    var curlRequest: String {
        var components = ["$ curl -v"]

        guard
            let _ = self.host
        else {
            return "$ curl command could not be created"
        }

        if method != "GET" {
            components.append("-X \(method)")
        }
        
        components += headers.map {
            let escapedValue = String(describing: $0.value).replacingOccurrences(of: "\"", with: "\\\"")
            return "-H \"\($0.key): \(escapedValue)\""
        }

        if let httpBodyData = httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            // the following replacingOccurrences handles cases where httpBody already contains the escape \ character before the double quotation mark (") character
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"") // \" -> \\\"
            // the following replacingOccurrences escapes the character double quotation mark (")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"") // " -> \"

            components.append("-d \"\(escapedBody)\"")
        }
        
        for credential in credentials {
            components.append("-u \(credential.0):\(credential.1)")
        }
        
        if let cookies = cookies {
            components.append("-b \"\(cookies[..<cookies.index(before: cookies.endIndex)])\"")
        }

        components.append("\"\(url)\"")

        return components.joined(separator: " \\\n\t")
    }
    
    var postmanItem: PMItem? {
        guard
            let url = URL(string: self.url),
            let scheme = self.scheme,
            let host = self.host
            else { return nil }
        
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "yyyyMMdd_HHmmss"
        
        let name = "\(dateFormatterGet.string(from: date))-\(url)"
        
        var headers: [PMHeader] = []
        let method = self.method
        for header in self.headers {
            headers.append(PMHeader(key: header.0, value: header.1))
        }
        
        var rawBody: String = ""
        if let httpBodyData = httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            rawBody = httpBody
        }
        
        let hostList = host.split(separator: ".")
            .map{ String(describing: $0) }
        
        var pathList = url.pathComponents
        pathList.removeFirst()

        let body = PMBody(mode: "raw", raw: rawBody)
        
        let query: [PMQuery]? = url.query?.split(separator: "&").compactMap{ element in
            let splittedElements = element.split(separator: "=")
            guard splittedElements.count == 2 else { return nil }
            let key = String(splittedElements[0])
            let value = String(splittedElements[1])
            return PMQuery(key: key, value: value)
        }

        let urlPostman = PMURL(raw: url.absoluteString, urlProtocol: scheme, host: hostList, path: pathList, query: query)
        let request = PMRequest(method: method, header: headers, body: body, url: urlPostman, description: "")
        
        // build response
        
        let responseHeaders = self.responseHeaders?.compactMap{ (key, value) in
            return PMHeader(key: key, value: value)
        } ?? []
        
        let responseBody: String
        if let data = dataResponse, let string = String(data: data, encoding: .utf8) {
            responseBody = string
        }
        else {
            responseBody = ""
        }
        
        let response = PMResponse(name: url.absoluteString, originalRequest: request, status: "", code: code, postmanPreviewlanguage: "html", header: responseHeaders, cookie: [], body: responseBody)
        
        return PMItem(name: name, item: nil, request: request, response: [response])
    }

    /// A short heading that identifies this request: GQL operation name, REST path, or fallback.
    /// Matches the identifiers shown in the original request list (query name, operation type, URL path).
    var displayHeading: String {
        if let name = graphqlOperationName, !name.isEmpty {
            if let type = graphqlOperationType, !type.isEmpty {
                return "\(type.capitalized): \(name)"
            }
            return name
        }
        if let urlObj = URL(string: url), !urlObj.path.isEmpty, urlObj.path != "/" {
            return urlObj.path
        }
        return host ?? url
    }

    /// Key for grouping: GQL by operation name + body (variables/query); others by method + URL.
    var groupingKey: String {
        if let opName = graphqlOperationName, !opName.isEmpty {
            let bodyStr = httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? url
            return "gql|\(method)|\(url)|\(opName)|\(bodyStr)"
        }
        return "rest|\(method)|\(url)"
    }

    /// Apollo operation name from legacy headers or GraphQL request payload.
    var graphqlOperationName: String? {
        if let headerName = headerValue(for: "X-APOLLO-OPERATION-NAME"), !headerName.isEmpty {
            return headerName
        }
        return graphQLPayload?.operationName
    }

    /// Apollo operation type from legacy headers or inferred from the GraphQL document.
    var graphqlOperationType: String? {
        if let headerType = headerValue(for: "X-APOLLO-OPERATION-TYPE"), !headerType.isEmpty {
            return headerType
        }
        return graphQLPayload?.operationType
    }

    private func headerValue(for name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private var graphQLPayload: GraphQLPayload? {
        if let body = httpBody, let payload = GraphQLPayload.parseJSONBody(body) {
            return payload
        }
        return GraphQLPayload.parseURLQuery(url)
    }
}

private struct GraphQLPayload {
    let operationName: String?
    let operationType: String?

    static func parseJSONBody(_ data: Data) -> GraphQLPayload? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["operationName"] != nil || json["query"] != nil || json["extensions"] != nil
        else {
            return nil
        }

        let operationName = json["operationName"] as? String
        let query = json["query"] as? String
        return GraphQLPayload(
            operationName: operationName,
            operationType: query.flatMap(inferOperationType(from:))
        )
    }

    static func parseURLQuery(_ urlString: String) -> GraphQLPayload? {
        guard
            let components = URLComponents(string: urlString),
            let queryItems = components.queryItems,
            queryItems.contains(where: { $0.name == "operationName" })
        else {
            return nil
        }

        let operationName = queryItems.first { $0.name == "operationName" }?.value
        let query = queryItems.first { $0.name == "query" }?.value
        return GraphQLPayload(
            operationName: operationName,
            operationType: query.flatMap(inferOperationType(from:))
        )
    }

    private static func inferOperationType(from query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("mutation") { return "mutation" }
        if trimmed.hasPrefix("subscription") { return "subscription" }
        if trimmed.hasPrefix("query") || trimmed.hasPrefix("{") { return "query" }
        return nil
    }
}
