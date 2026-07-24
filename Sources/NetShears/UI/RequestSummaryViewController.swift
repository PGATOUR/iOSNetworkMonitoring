//
//  RequestSummaryViewController.swift
//  NetShears
//
//  Shows unique requests with occurrence count, sorted by most to least.
//

import UIKit
import SwiftUI

final class RequestSummaryViewController: UIViewController {

    private var allGroupedRequests: [GroupedRequest] = []

    private var showOnlyGQLRequests: Bool = false
    private var showOnlyRESTRequests: Bool = false
    private var showGQLandREST: Bool = false
    private var filterOutConnectivityPing: Bool = true
    private var cloudinaryImagesOnly: Bool = false

    private var searchController: UISearchController?

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 88
        table.register(UITableViewCell.self, forCellReuseIdentifier: RequestSummaryViewController.cellId)
        return table
    }()

    private static let cellId = "GroupedRequestCell"
    weak var delegate: BodyExporterDelegate?

    /// - Parameters:
    ///   - requests: Initial request list (e.g. from main screen's filtered list). If nil, uses Storage and filter state.
    ///   - showOnlyGQLRequests: Initial filter state (matches main list when opened from there).
    ///   - showOnlyRESTRequests: Initial filter state.
    ///   - showGQLandREST: Initial filter state.
    ///   - filterOutConnectivityPing: Initial filter state.
    ///   - cloudinaryImagesOnly: Initial filter state.
    init(requests: [NetShearsRequestModel]? = nil,
         showOnlyGQLRequests: Bool = false,
         showOnlyRESTRequests: Bool = false,
         showGQLandREST: Bool = false,
         filterOutConnectivityPing: Bool = true,
         cloudinaryImagesOnly: Bool = false) {
        self.showOnlyGQLRequests = showOnlyGQLRequests
        self.showOnlyRESTRequests = showOnlyRESTRequests
        self.showGQLandREST = showGQLandREST
        self.filterOutConnectivityPing = filterOutConnectivityPing
        self.cloudinaryImagesOnly = cloudinaryImagesOnly
        super.init(nibName: nil, bundle: nil)
        if let requests = requests {
            allGroupedRequests = GroupedRequest.grouped(from: requests)
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "By request count"
        view.backgroundColor = UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        addNavigationItems()
        addSearchController()
        if allGroupedRequests.isEmpty {
            reloadGroupedRequests()
        }
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NewRequestNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.reloadGroupedRequests() }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NewRequestNotification, object: nil)
    }

    private func addNavigationItems() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Filters",
            style: .plain,
            target: self,
            action: #selector(openFilterActionSheet(_:))
        )
    }

    private func addSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.searchBar.placeholder = "Search"
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }

    private var displayedGroupedRequests: [GroupedRequest] {
        filterGroupedRequests(text: searchController?.searchBar.text)
    }

    private func filterGroupedRequests(text: String?) -> [GroupedRequest] {
        guard
            let searchText = text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !searchText.isEmpty
        else {
            return allGroupedRequests
        }

        return allGroupedRequests.filter { matchesSearch($0, searchText: searchText) }
    }

    private func matchesSearch(_ grouped: GroupedRequest, searchText: String) -> Bool {
        let options: String.CompareOptions = .caseInsensitive

        if grouped.url.range(of: searchText, options: options) != nil { return true }
        if grouped.method.range(of: searchText, options: options) != nil { return true }
        if grouped.latestRequest.displayHeading.range(of: searchText, options: options) != nil { return true }

        if let operationName = grouped.latestRequest.graphqlOperationName,
           operationName.range(of: searchText, options: options) != nil {
            return true
        }

        if let operationType = grouped.latestRequest.graphqlOperationType,
           operationType.range(of: searchText, options: options) != nil {
            return true
        }

        return false
    }

    private func applyFilters() -> [NetShearsRequestModel] {
        Storage.shared.filteredRequests.filter {
            checkForFiltering(url: $0.url) &&
            checkForFiltingConnectivity(url: $0.url) &&
            checkForFilteringCloudinaryImages(url: $0.url)
        }
    }

    private func checkForFiltering(url: String) -> Bool {
        if showOnlyGQLRequests {
            return url.localizedCaseInsensitiveContains("orchestrator")
        }
        if showOnlyRESTRequests {
            return url.localizedCaseInsensitiveContains("data-api-uat")
        }
        if showGQLandREST {
            return url.localizedCaseInsensitiveContains("orchestrator-uat") ||
                url.localizedCaseInsensitiveContains("data-api-uat")
        }
        return true
    }

    private func checkForFiltingConnectivity(url: String) -> Bool {
        guard filterOutConnectivityPing else { return true }
        return !url.contains("pgatour.com/hotspot-detect")
    }

    private func checkForFilteringCloudinaryImages(url: String) -> Bool {
        guard cloudinaryImagesOnly else { return true }
        return url.contains("cloudinary")
    }

    private func reloadGroupedRequests() {
        allGroupedRequests = GroupedRequest.grouped(from: applyFilters())
        tableView.reloadData()
    }

    private func syncFilterStateToShared() {
        let state = NetworkMonitorFilterState.shared
        state.showOnlyGQLRequests = showOnlyGQLRequests
        state.showOnlyRESTRequests = showOnlyRESTRequests
        state.showGQLandREST = showGQLandREST
        state.filterOutConnectivityPing = filterOutConnectivityPing
        state.cloudinaryImagesOnly = cloudinaryImagesOnly
    }

    @objc private func openFilterActionSheet(_ sender: UIBarButtonItem) {
        let filtersVC = UIHostingController(
            rootView: FiltersView(
                showOnlyGQLQueries: showOnlyGQLRequests,
                showOnlyRestRequest: showOnlyRESTRequests,
                showGQLandREST: showGQLandREST,
                filterOutConnectivityPing: filterOutConnectivityPing,
                cloudinaryImagesOnly: cloudinaryImagesOnly
            ) { [weak self] gql, rest, gqlAndRest, filterOutConnectivityPing, cloudinaryImagesOnly in
                self?.showOnlyGQLRequests = gql
                self?.showOnlyRESTRequests = rest
                self?.showGQLandREST = gqlAndRest
                self?.filterOutConnectivityPing = filterOutConnectivityPing
                self?.cloudinaryImagesOnly = cloudinaryImagesOnly
                self?.syncFilterStateToShared()
                self?.reloadGroupedRequests()
            }
        )
        present(filtersVC, animated: true, completion: nil)
    }

    private func openRequestDetail(_ grouped: GroupedRequest) {
        let storyboard = UIStoryboard.NetShearsStoryBoard
        guard let detailVC = storyboard.instantiateViewController(withIdentifier: String(describing: RequestDetailViewController.self)) as? RequestDetailViewController else { return }
        detailVC.request = grouped.latestRequest
        detailVC.delegate = delegate
        show(detailVC, sender: self)
    }
}

extension RequestSummaryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedGroupedRequests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RequestSummaryViewController.cellId, for: indexPath)
        let grouped = displayedGroupedRequests[indexPath.row]
        let heading = grouped.latestRequest.displayHeading
        let countText = "\(grouped.method.uppercased()) • \(grouped.fulfillmentCountText)"
        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = heading
            config.textProperties.font = .systemFont(ofSize: 17, weight: .semibold)
            config.textProperties.numberOfLines = 0
            config.secondaryText = "\(countText)\n\(grouped.url)"
            config.secondaryTextProperties.numberOfLines = 0
            config.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = "\(heading)\n\(countText)\n\(grouped.url)"
            cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            cell.textLabel?.numberOfLines = 0
        }
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .systemBackground
        return cell
    }
}

extension RequestSummaryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openRequestDetail(displayedGroupedRequests[indexPath.row])
    }
}

extension RequestSummaryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        tableView.reloadData()
    }
}
