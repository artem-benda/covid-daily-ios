//
//  SummaryCollectionViewCell.swift
//  CovidDaily
//
//  Created by Artem Benda on 14.03.2021.
//

import UIKit

class SummaryCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var countryNameLabel: UILabel!
    @IBOutlet weak var confirmedLabel: UILabel!
    @IBOutlet weak var deathsLabel: UILabel!
    @IBOutlet weak var recoveredLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
}
