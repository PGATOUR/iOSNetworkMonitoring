//
//  RequestsViewController.swift
//  NetShears
//
//  Created by Mehdi Mirzaie on 6/1/21.
//
//

import UIKit
import SwiftUI

class RequestsViewController: UIViewController, ShowLoaderProtocol {
    
    @IBOutlet weak var collectionView: UICollectionView!
    weak var delegate: BodyExporterDelegate?

    private var filteredRequests: [NetShearsRequestModel] = Storage.shared.filteredRequests
    
    private var searchController: UISearchController?
    private let requestCellIdentifier = String(describing: RequestCell.self)

    private var showOnlyGQLRequests: Bool = false
    private var showOnlyRESTRequests: Bool = false
    private var showGQLandREST = false
    private var filterOutConnectivityPing = true
    private var cloudinaryImagesOnly = false
        
    var defaultFilterText: String = ""
    var doneAction: (() -> Void)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        syncFilterStateFromShared()
        addNavigationItems()
        addSearchController()
        registerNibs()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NewRequestNotification, object: nil, queue: nil) { [weak self] (notification) in
            DispatchQueue.main.async { [weak self] in
                self?.filteredRequests = self?.filterRequests(text: self?.searchController?.searchBar.text) ?? []
                self?.collectionView.reloadData()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncFilterStateFromShared()
        filteredRequests = filterRequests(text: searchController?.searchBar.text) ?? []
        collectionView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController?.searchBar.text = defaultFilterText
    }

    private func syncFilterStateFromShared() {
        let state = NetworkMonitorFilterState.shared
        showOnlyGQLRequests = state.showOnlyGQLRequests
        showOnlyRESTRequests = state.showOnlyRESTRequests
        showGQLandREST = state.showGQLandREST
        filterOutConnectivityPing = state.filterOutConnectivityPing
        cloudinaryImagesOnly = state.cloudinaryImagesOnly
    }

    private func syncFilterStateToShared() {
        let state = NetworkMonitorFilterState.shared
        state.showOnlyGQLRequests = showOnlyGQLRequests
        state.showOnlyRESTRequests = showOnlyRESTRequests
        state.showGQLandREST = showGQLandREST
        state.filterOutConnectivityPing = filterOutConnectivityPing
        state.cloudinaryImagesOnly = cloudinaryImagesOnly
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func registerNibs() {
        collectionView?.register(UINib(nibName: String(describing: RequestCell.self), bundle: Bundle.NetShearsBundle), forCellWithReuseIdentifier: requestCellIdentifier)
    }
    
    //  MARK: - Search
    
    private func addSearchController(){
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        if #available(iOS 9.1, *) {
            searchController?.obscuresBackgroundDuringPresentation = false
        } else {
            // Fallback
        }
        searchController?.searchBar.placeholder = "Search"
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchController?.searchBar
        }
        definesPresentationContext = true
    }
    
    private func filterRequests(text: String?) -> [NetShearsRequestModel]{
        return Storage.shared.filteredRequests.filter {
            checkForSearchFiltering(text: text, requestModel: $0) &&
            checkForFiltingConnectivity(url: $0.url) &&
            checkForFilteringCloudinaryImages(url: $0.url) &&
            checkForFiltering(url: $0.url)
        }
    }
    
    private func checkForSearchFiltering(text: String?, requestModel: NetShearsRequestModel) -> Bool {
        guard let searchText = text, !searchText.isEmpty else { return true }
        
        return requestModel.url.range(of: searchText, options: .caseInsensitive) != nil ||
        requestModel.headers.values.contains(where: { $0.range(of: searchText, options: .caseInsensitive) != nil })
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
            url.localizedCaseInsensitiveContains( "data-api-uat")
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
    
    // MARK: - Actions
    
    @objc private func openActionSheet(_ sender: UIBarButtonItem){
        let ac = UIAlertController(title: "Wormholy", message: "Choose an option", preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Clear", style: .default) { [weak self] (action) in
            self?.clearRequests()
        })
        ac.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] (action) in
            self?.shareContent(sender)
        })
        
        ac.addAction(UIAlertAction(title: "Share as cURL", style: .default) { [weak self] (action) in
            self?.shareContent(sender, requestExportOption: .curl)
        })
        ac.addAction(UIAlertAction(title: "Share as Postman Collection", style: .default) { [weak self] (action) in
                   self?.shareContent(sender, requestExportOption: .postman)
               })
        ac.addAction(UIAlertAction(title: "Close", style: .cancel) { (action) in
        })
        if UIDevice.current.userInterfaceIdiom == .pad {
            ac.popoverPresentationController?.barButtonItem = sender
        }
        present(ac, animated: true, completion: nil)
    }

    @objc private func openRequestSummary(_ sender: UIBarButtonItem?) {
        let summaryVC = RequestSummaryViewController(
            requests: filteredRequests,
            showOnlyGQLRequests: showOnlyGQLRequests,
            showOnlyRESTRequests: showOnlyRESTRequests,
            showGQLandREST: showGQLandREST,
            filterOutConnectivityPing: filterOutConnectivityPing,
            cloudinaryImagesOnly: cloudinaryImagesOnly
        )
        summaryVC.delegate = delegate
        show(summaryVC, sender: self)
    }

    private func clearRequests() {
        Storage.shared.clearRequests()
        filteredRequests = Storage.shared.filteredRequests
        collectionView.reloadData()
    }
    
    private func shareContent(_ sender: UIBarButtonItem, requestExportOption: RequestResponseExportOption = .flat){
        NSHelper.shareRequests(presentingViewController: self, sender: sender, requests: filteredRequests, requestExportOption: requestExportOption, delegate: delegate)
    }
    
    // MARK: - Navigation
    
    private func addNavigationItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "More", style: .plain, target: self, action: #selector(openActionSheet(_:)))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done)),
            UIBarButtonItem(title: "Filters", style: .plain, target: self, action: #selector(openFilterActionSheet(_:))),
            UIBarButtonItem(title: "By count", style: .plain, target: self, action: #selector(openRequestSummary(_:)))
        ]
    }
    
    @objc private func done(){
        if let doneAction = doneAction {
            doneAction()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
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
                self?.filteredRequests = self?.filterRequests(text: self?.searchController?.searchBar.text) ?? []
                self?.collectionView.reloadData()
            }
        )
        
        present(filtersVC, animated: true, completion: nil)
    }
    
    private func openRequestDetailVC(request: NetShearsRequestModel){
        defaultFilterText = searchController?.searchBar.text ?? ""
        
        let storyboard = UIStoryboard.NetShearsStoryBoard
        if let requestDetailVC = storyboard.instantiateViewController(withIdentifier: String(describing: RequestDetailViewController.self)) as? RequestDetailViewController{
            requestDetailVC.request = request
            requestDetailVC.delegate = delegate
            self.show(requestDetailVC, sender: self)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NewRequestNotification, object: nil)
    }
}

extension RequestsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredRequests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: requestCellIdentifier, for: indexPath) as! RequestCell
        
        cell.populate(request: filteredRequests[indexPath.item])
        return cell
    }
}

extension RequestsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openRequestDetailVC(request: filteredRequests[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.size.width
        let height = RequestCell.preferredHeight(for: filteredRequests[indexPath.item], width: width)
        return CGSize(width: width, height: height)
    }
}

// MARK: - UISearchResultsUpdating Delegate
extension RequestsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filteredRequests = filterRequests(text: searchController.searchBar.text)
        collectionView.reloadData()
    }
}
