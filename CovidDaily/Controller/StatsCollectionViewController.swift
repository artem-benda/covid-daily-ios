//
//  StatsCollectionViewController.swift
//  CovidDaily
//
//  Created by Artem Benda on 10.03.2021.
//

import UIKit
import CoreData

class StatsCollectionViewController: UIViewController {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var collectionViewOperations: [BlockOperation] = []
    
    var apiTask: URLSessionTask? = nil
    
    var dataController: DataController!
    var fetchedResultController: NSFetchedResultsController<CountrySummary>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let columnLayout = ColumnFlowLayout(
                    cellsPerRow: 1,
                    cellHeight: 120,
                    minimumInteritemSpacing: 10,
                    minimumLineSpacing: 10,
                    sectionInset: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                )
        collectionView.setCollectionViewLayout(columnLayout, animated: true)
        searchBar.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupFetchedResultController()
        startGetSummaryRequest()

        if let indexPaths = collectionView.indexPathsForSelectedItems, !indexPaths.isEmpty {
            indexPaths.forEach { (indexPath) in
                collectionView.deselectItem(at: indexPath, animated: true)
            }
            collectionView.reloadItems(at: indexPaths)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        fetchedResultController = nil
    }
    
    deinit {
        for o in collectionViewOperations { o.cancel() }
        collectionViewOperations.removeAll()
    }
    
    @IBAction func startGetSummaryRequest() {
        apiTask?.cancel()
        displayAnimatedActivityIndicatorView()
        apiTask = CovidApiClient.getSummary(completionHandler: handleGetSummaryResponse)
    }
    
    func handleGetSummaryResponse(dtos: [CountrySummaryDto]?, error: Error?) {
        hideAnimatedActivityIndicatorView()
        
        guard error == nil else {
            showErrorAlert(message: error?.localizedDescription ?? "Error getting data from server. Please, try again later")
            return
        }
        
        guard let dtos = dtos, let entites = fetchedResultController.fetchedObjects else {
            print("Nothing to update or upload")
            return
        }
        
        let backgroundContext = dataController.backgroundContext!
        backgroundContext.perform {
            dtos.forEach { (dto) in
                // Filter by country identifier
                let summary = entites.filter { (entity) -> Bool in
                    entity.slug == dto.slug
                }.first
                
                var entity: CountrySummary!
                
                if summary == nil {
                    entity = CountrySummary(context: backgroundContext)
                } else {
                    entity = (backgroundContext.object(with: summary!.objectID) as! CountrySummary)
                }
                
                entity.asOf = dto.asOf
                entity.countryName = dto.countryName
                entity.countryCode = dto.countryCode
                entity.slug = dto.slug
                entity.newConfirmed = Int64(dto.newConfirmed)
                entity.totalConfirmed = Int64(dto.totalConfirmed)
                entity.newDeaths = Int64(dto.newDeaths)
                entity.totalDeaths = Int64(dto.totalDeaths)
                entity.newRecovered = Int64(dto.newRecovered)
                entity.totalRecovered = Int64(dto.totalRecovered)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                self.showErrorAlert(message: "Error saving data to local database: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupFetchedResultController() {
        print("setupFetchedResultController, start")
        let fetchRequest: NSFetchRequest<CountrySummary> = CountrySummary.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "countryName", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        if let searchText = searchBar.text, !searchText.isEmpty {
            print("setupFetchedResultController, predicate with search text = \(searchText)")
            let predicate = NSPredicate(format: "(countryName CONTAINS[cd] %@)", searchText)
            fetchRequest.predicate = predicate
        }
        
        NSFetchedResultsController<CountrySummary>.deleteCache(withName: "summary")
        fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "summary")
        fetchedResultController.delegate = self
        
        do {
            try fetchedResultController.performFetch()
            collectionView.reloadData()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
}

extension StatsCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let fetchedObjects = fetchedResultController.fetchedObjects
        guard fetchedObjects != nil, indexPath.row < fetchedObjects!.count else { return }
        if let countrySummaryItem = fetchedResultController.fetchedObjects?[indexPath.row] {
            performSegue(withIdentifier: "showDetails", sender: countrySummaryItem)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetails" {
            let detailsViewController = segue.destination as! DetailsViewController
            detailsViewController.summary = sender as? CountrySummary
            detailsViewController.dataController = dataController
        }
    }
}

extension StatsCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "summaryCell", for: indexPath) as! SummaryCollectionViewCell
        // Get model
        let fetchedObjects = fetchedResultController.fetchedObjects
        guard fetchedObjects != nil, indexPath.row < fetchedObjects!.count else { return cell }
        if let summary = fetchedResultController.fetchedObjects?[indexPath.row] {
            cell.countryNameLabel.text = summary.countryName
            cell.confirmedLabel.text = "\(summary.newConfirmed) confirmed new of \(summary.totalConfirmed) total"
            cell.deathsLabel.text = "\(summary.newDeaths) deaths new of \(summary.totalDeaths) total"
            cell.recoveredLabel.text = "\(summary.newRecovered) recovered new of \(summary.totalRecovered) total"
            cell.dateLabel.text = DateFormatter.localizedString(
                from: summary.asOf!,
                dateStyle: .long,
                timeStyle: .long
            )
        }
        return cell
    }
}

extension StatsCollectionViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        setupFetchedResultController()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
}

extension StatsCollectionViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
            case .insert:
                collectionViewOperations.append(BlockOperation(block: { [weak self] in
                    self!.collectionView.insertItems(at: [newIndexPath!])
                }))
            case .delete:
                collectionViewOperations.append(BlockOperation(block: { [weak self] in
                    self!.collectionView.deleteItems(at: [indexPath!])
                }))
            case .update:
                collectionViewOperations.append(BlockOperation(block: { [weak self] in
                    self!.collectionView.reloadItems(at: [indexPath!])
                }))
            case .move:
                collectionViewOperations.append(BlockOperation(block: { [weak self] in
                    // self!.collectionView.moveItem(at: indexPath!, to: newIndexPath!)
                    self!.collectionView.deleteItems(at: [indexPath!])
                    self!.collectionView.insertItems(at: [newIndexPath!])
                }))
            default:
                break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates({ () -> Void in
            for op: BlockOperation in self.collectionViewOperations { op.start() }
        }, completion: { (finished) -> Void in self.collectionViewOperations.removeAll() })
    }
}
