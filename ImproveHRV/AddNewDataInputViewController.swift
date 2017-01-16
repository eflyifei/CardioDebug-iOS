//
//  AddNewDataInputViewController.swift
//  ImproveHRV
//
//  Created by Arefly on 1/15/17.
//  Copyright © 2017 Arefly. All rights reserved.
//

import UIKit
import Foundation
import Async
import RealmSwift

class AddNewDataInputViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
	// MARK: - static var
	static let SHOW_INPUT_TABLE_VIEW = "showInputTableView"

	let cellID = "inputCell"

	@IBOutlet var tableView: UITableView!

	var viewTitle = ""
	var cellTitle = [String]()
	var cellPlaceholder = [String]()

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.delegate = self
		tableView.dataSource = self

		self.title = viewTitle

		let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(self.saveButtonAction))
		self.navigationItem.setRightBarButton(saveButton, animated: true)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func saveButtonAction() {
		switch viewTitle {
		case "Blood Pressure":
			let systolicCell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0))! as! TextFieldInputTableCell
			let diastolicCell = self.tableView.cellForRow(at: IndexPath(row: 1, section: 0))! as! TextFieldInputTableCell
			let heartRateCell = self.tableView.cellForRow(at: IndexPath(row: 2, section: 0))! as! TextFieldInputTableCell

			if let systolicText = systolicCell.textField.text, let diastolicText = diastolicCell.textField.text {
				if let systolicValue = Double(systolicText), let diastolicValue = Double(diastolicText) {
					let nowDate = Date()

					HealthManager.saveBloodPressure(date: nowDate, systolic: systolicValue, diastolic: diastolicValue) { (success, error) -> Void in
						print("BP save state: \(success), \(error)")
						if let _ = error {
							HelperFunctions.showAlert(self, title: "Error", message: "Please add the blood pressure manually in Health app!", completion: nil)
						}

						let realm = try! Realm()
						let bloodPressureData = BloodPressureData()
						bloodPressureData.date = nowDate
						bloodPressureData.systoloc = systolicValue
						bloodPressureData.diastolic = diastolicValue

						var shouldDismiss = true

						if let heartRateText = heartRateCell.textField.text {
							if let heartRateValue = Double(heartRateText) {
								print("Heart rate have value")
								shouldDismiss = false
								bloodPressureData.heartRate = heartRateValue
								HealthManager.saveHeartRate(date: nowDate, heartRate: heartRateValue) { (success, error) -> Void in
									// HR data is write only. All read will come from Realm
									print("HR save state: \(success), \(error)")
									if let _ = error {
										HelperFunctions.showAlert(self, title: "Error", message: "Please add the heart rate manually in Health app!", completion: nil)
									}
									self.dismiss(animated: true, completion: nil)
								}
							}
						}

						try! realm.write {
							realm.add(bloodPressureData)
						}

						if shouldDismiss {
							self.dismiss(animated: true, completion: nil)
						}
					}
				} else {
					HelperFunctions.showAlert(self, title: "Notice", message: "Please enter correct value!", completion: nil)
				}
			}
			break
		default:
			break
		}
	}

	// MARK: - tableView related
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return cellTitle.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: cellID)! as! TextFieldInputTableCell

		cell.titleLabel.text = cellTitle[indexPath.row]
		cell.textField.placeholder = cellPlaceholder[indexPath.row]
		cell.textField.text = ""
		cell.textField.keyboardType = .decimalPad

		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cell = self.tableView.cellForRow(at: indexPath)! as! TextFieldInputTableCell
		cell.textField.becomeFirstResponder()
		self.tableView.deselectRow(at: indexPath, animated: true)
	}
}

class TextFieldInputTableCell: UITableViewCell {
	@IBOutlet var titleLabel: UILabel!
	@IBOutlet var textField: UITextField!
}
