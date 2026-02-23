//
//  NetworkMonitorFilterState.swift
//  NetShears
//
//  Shared filter state so the main request list and "By count" summary retain the user's filter selection.
//

import Foundation

/// Shared filter state for the network monitor request list and by-count summary.
final class NetworkMonitorFilterState {
    static let shared = NetworkMonitorFilterState()

    var showOnlyGQLRequests: Bool = false
    var showOnlyRESTRequests: Bool = false
    var showGQLandREST: Bool = false
    var filterOutConnectivityPing: Bool = true
    var cloudinaryImagesOnly: Bool = false

    private init() {}
}
