//
//  AddNewDataViewController.swift
//  ImproveHRV
//
//  Created by Arefly on 1/14/17.
//  Copyright © 2017 Arefly. All rights reserved.
//

import UIKit
import Foundation

class AddNewDataViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	// MARK: - static var
	static let PRESENT_ADD_DATA_VIEW = "presentAddDataView"

	@IBOutlet var tableView: UITableView!

	var tableData = [String]()
	var cellTitleToBePassed = [String]()
	var cellPlaceholderToBePassed = [String]()

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self

		self.title = "Add"

		tableData = ["Blood Pressure", "Height & Weight", "Body Temperature"]
		cellTitleToBePassed = ["Systoloc|Diastolic|Heart Rate (bpm)", "Height (m)|Weight (kg)", "°C"]
		cellPlaceholderToBePassed = ["||(optional)", "|", ""]

		let closeButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.closeButtonAction))
		self.navigationItem.setLeftBarButton(closeButton, animated: true)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == AddNewDataInputViewController.SHOW_INPUT_TABLE_VIEW {
			if let destination = segue.destination as? AddNewDataInputViewController {
				if let indexPath: IndexPath = self.tableView.indexPathForSelectedRow {
					let viewTitle = tableData[indexPath.row]
					destination.viewTitle = viewTitle
					destination.cellTitle = cellTitleToBePassed[indexPath.row].components(separatedBy: "|")
					destination.cellPlaceholder = cellPlaceholderToBePassed[indexPath.row].components(separatedBy: "|")
				}
			}
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func closeButtonAction() {
		self.dismiss(animated: true, completion: nil)
	}

	// MARK: - tableView related
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tableData.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
		cell.textLabel?.text = tableData[indexPath.row]
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		self.tableView.deselectRow(at: indexPath, animated: true)
	}
}
