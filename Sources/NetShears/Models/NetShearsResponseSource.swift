//
//  NetShearsResponseSource.swift
//  NetShears
//
//  Indicates whether URLSession fulfilled a logged request from HTTP cache or the network.
//

import Foundation

public enum NetShearsResponseSource: String, Codable {
    case network
    case cache
    case unknown

    init(resourceFetchType: URLSessionTaskMetrics.ResourceFetchType?) {
        switch resourceFetchType {
        case .localCache:
            self = .cache
        case .networkLoad, .serverPush:
            self = .network
        default:
            self = .unknown
        }
    }

    var displayLabel: String {
        switch self {
        case .network:
            return "Network"
        case .cache:
            return "Cache"
        case .unknown:
            return "Unknown"
        }
    }
}

extension NetShearsRequestModel {
    func applyResponseSource(from metrics: URLSessionTaskMetrics) {
        responseSource = NetShearsResponseSource(
            resourceFetchType: metrics.transactionMetrics.last?.resourceFetchType
        )
    }

    var durationWithSourceLabel: String {
        let durationText = duration?.formattedMilliseconds() ?? ""
        guard isFinished, let responseSource, responseSource != .unknown else {
            return durationText
        }

        if durationText.isEmpty {
            return responseSource.displayLabel
        }

        return "\(durationText) · \(responseSource.displayLabel)"
    }
}
