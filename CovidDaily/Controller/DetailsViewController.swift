//
//  DetailsViewController.swift
//  CovidDaily
//
//  Created by Artem Benda on 15.03.2021.
//

import UIKit
import CoreData

class DetailsViewController: UIViewController {
    
    var dataMode: CovidApiClient.CovidCasesStatus! {
        didSet {
            guard oldValue != dataMode else { return }
            setupFetchedResultController()
            setupTitle()
            configureUI()
            startGetDetailsRequest()
        }
    }
    let favouriteModeTagKey = "key_favourite_mode"
    
    var favouriteModeTag: Int {
        get {
            return UserDefaults.standard.integer(forKey: favouriteModeTagKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: favouriteModeTagKey)
        }
    }

    @IBOutlet weak var bookmarkButtonItem: UIBarButtonItem!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var collectionViewOperations: [BlockOperation] = []
    
    var apiTask: URLSessionTask? = nil
    
    var dataController: DataController!
    var fetchedResultController: NSFetchedResultsController<DetailsByDate>!
    
    var summary: CountrySummary!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let columnLayout = ColumnFlowLayout(
                    cellsPerRow: 1,
                    cellHeight: 40,
                    minimumInteritemSpacing: 10,
                    minimumLineSpacing: 10,
                    sectionInset: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                )
        collectionView.setCollectionViewLayout(columnLayout, animated: true)

        setModeForTag(favouriteModeTag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

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
    
    @IBAction func handleSwitchMode(_ sender: UIBarButtonItem) {
        setModeForTag(sender.tag)
    }
    
    @IBAction func handleBookmarkMode(_ sender: Any) {
        let alert = UIAlertController(title: "Bookmark tab", message: "Do you really want to set this tab as default when open details?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
            self.favouriteModeTag = self.dataMode.tag
            self.configureUI()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func handleRefresh(_ sender: Any) {
        startGetDetailsRequest()
    }
    
    private func setupTitle() {
        switch dataMode {
        case .confirmed:
            title = "Confirmed: \(summary.countryName!)"
        case .deaths:
            title = "Deaths: \(summary.countryName!)"
        case .recovered:
            title = "Recovered: \(summary.countryName!)"
        default:
            title = ""
        }
    }
    
    private func setModeForTag(_ tag: Int) {
        switch tag {
        case 0:
            dataMode = .confirmed
        case 1:
            dataMode = .deaths
        case 2:
            dataMode = .recovered
        default:
            dataMode = .confirmed
        }
    }
    
    private func setupFetchedResultController() {
        print("setupFetchedResultController, start")
        let fetchRequest: NSFetchRequest<DetailsByDate> = DetailsByDate.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "asOf", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        let predicate = NSPredicate(format: "(tag = %@)", NSNumber(value: dataMode.tag))
        fetchRequest.predicate = predicate
        
        let cacheName = "details-\(summary.slug!)-\(dataMode!)"
        NSFetchedResultsController<DetailsByDate>.deleteCache(withName: cacheName)
        fetchedResultController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: cacheName)
        fetchedResultController.delegate = self
        
        do {
            try fetchedResultController.performFetch()
            collectionView.reloadData()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    private func startGetDetailsRequest() {
        apiTask?.cancel()
        displayAnimatedActivityIndicatorView()
        apiTask = CovidApiClient.getConfirmedDetailsByCountryAndState(slug: summary.slug!, state: dataMode, completionHandler: handleGetDetailsResult)
    }
    
    func handleGetDetailsResult(dtos: [TotalByDateDto]?, error: Error?) {
        hideAnimatedActivityIndicatorView()
        
        guard error == nil else {
            print("Error: \(String(describing: error))")
            showErrorAlert(message: error?.localizedDescription ?? "Error getting data from server. Please, try again later")
            return
        }
        
        guard let dtos = dtos, let entites = fetchedResultController.fetchedObjects else {
            print("Nothing to update or upload")
            return
        }
        
        let backgroundContext = dataController.backgroundContext!
        backgroundContext.perform {
            // Taking only last values for same day
            var dtoDictionary = Dictionary<Date, TotalByDateDto>()
            dtos.forEach { (dto) in
                if dtoDictionary[dto.asOf] == nil || dtoDictionary[dto.asOf]?.cases ?? 0 < dto.cases {
                    dtoDictionary[dto.asOf] = dto
                }
            }
            
            dtoDictionary.values.forEach { (dto) in
                // Filter by country identifier
                let detail = entites.filter { (entity) -> Bool in
                    entity.asOf == dto.asOf
                }.first
                
                var entity: DetailsByDate!
                
                if detail == nil {
                    entity = DetailsByDate(context: backgroundContext)
                } else {
                    entity = (backgroundContext.object(with: detail!.objectID) as! DetailsByDate)
                }
                
                entity.asOf = dto.asOf
                entity.cases = Int64(dto.cases)
                entity.tag = Int16(self.dataMode.tag)
            }
            
            do {
                try backgroundContext.save()
            } catch {
                self.showErrorAlert(message: "Error saving data to local database: \(error.localizedDescription)")
            }
        }
    }
    
    private func configureUI() {
        let favouriteTag = favouriteModeTag
        bookmarkButtonItem.isEnabled = favouriteTag != dataMode.tag
        var icon: UIImage
        if favouriteTag == dataMode.tag {
            icon = UIImage(systemName: "bookmark.fill")!
        } else {
            icon = UIImage(systemName: "bookmark")!
        }
        bookmarkButtonItem.image = icon
    }
}

extension DetailsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultController.sections?[section].numberOfObjects ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "detailCell", for: indexPath) as! DetailCollectionViewCell
        // Get model
        let fetchedObjects = fetchedResultController.fetchedObjects
        guard fetchedObjects != nil, indexPath.row < fetchedObjects!.count else { return cell }
        if let detail = fetchedResultController.fetchedObjects?[indexPath.row] {
            cell.dateLabel.text = DateFormatter.localizedString(
                from: detail.asOf!,
                dateStyle: .long,
                timeStyle: .none
            )
            cell.countLabel.text = "\(detail.cases)"
        }
        return cell
    }
}

extension DetailsViewController: NSFetchedResultsControllerDelegate {
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
