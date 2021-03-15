//
//  ViewController+showErrorAlert+extension.swift
//  On the Map
//
//  Created by Artem Benda on 10.01.2021.
//

import Foundation
import UIKit

extension UIViewController {
    func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            // create the alert
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertController.Style.alert)

            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

            // show the alert
            self.present(alert, animated: true, completion: nil)
        }
    }
}
