//
//  GroupedRequest.swift
//  NetShears
//
//  Unique request key (method + url) with occurrence count and latest instance for detail.
//

import Foundation

/// Represents a unique request with how many times it occurred and the most recent instance.
/// GQL: unique by operation name + body (variables/query). REST/other: unique by method + URL.
struct GroupedRequest {
    let method: String
    let url: String
    let count: Int
    /// Most recent request in the group, used when opening detail.
    let latestRequest: NetShearsRequestModel

    /// Builds grouped requests: GQL by operation name + parameters (body); others by method + URL. Sorted by count descending.
    static func grouped(from requests: [NetShearsRequestModel]) -> [GroupedRequest] {
        let grouped = Dictionary(grouping: requests) { (req: NetShearsRequestModel) -> String in
            req.groupingKey
        }
        return grouped
            .map { _, reqs in
                let sorted = reqs.sorted { $0.date > $1.date }
                return GroupedRequest(
                    method: sorted[0].method,
                    url: sorted[0].url,
                    count: sorted.count,
                    latestRequest: sorted[0]
                )
            }
            .sorted { $0.count > $1.count }
    }
}
