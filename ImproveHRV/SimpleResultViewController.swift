//
//  SimpleResultViewController.swift
//  ImproveHRV
//
//  Created by Arefly on 18/12/2016.
//  Copyright © 2016 Arefly. All rights reserved.
//

import UIKit
import Foundation

class SimpleResultViewController: UIViewController {

	// MARK: - static var
	static let SHOW_SIMPLE_RESULT_SEGUE_ID = "showSimpleResultView"

	// MARK: - basic var
	let application = UIApplication.shared

	// MARK: - IBOutlet var
	@IBOutlet var upperLabel: UILabel!
	@IBOutlet var mainLabel: UILabel!
	@IBOutlet var mainTextView: UITextView!
	@IBOutlet var leftButton: UIButton!
	@IBOutlet var rightButton: UIButton!

	// MARK: - init var
	var currentState = 0

	// MARK: - data var
	var symptoms = [String]()


	// MARK: - override var
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	// MARK: - override func
	override func viewDidLoad() {
		super.viewDidLoad()

		symptoms = ["Headache", "Heart attack"]

		leftButton.isHidden = true
		leftButton.addTarget(self, action: #selector(self.leftButtonAction), for: .touchUpInside)

		rightButton.setTitle("Next", for: .normal)
		rightButton.addTarget(self, action: #selector(self.rightButtonAction), for: .touchUpInside)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	// MARK: - button action
	func leftButtonAction() {
		if currentState > 0 {
			appendState()
		}
	}

	func rightButtonAction() {
		appendState()
	}

	func appendState() {
		switch currentState {
		case 0:
			leftButton.setTitle("Yes", for: .normal)
			leftButton.isHidden = false
			rightButton.setTitle("No", for: .normal)
			mainLabel.text = "Did you feel..."
			mainTextView.text = "\(symptoms[currentState])?"
			upperLabel.text = "?"
			break
		case symptoms.count:
			leftButton.isHidden = true
			rightButton.setTitle("Close", for: .normal)
			mainLabel.text = "Recommendation:"
			mainTextView.text = "GO HOSPITAL NOW"
			upperLabel.text = "!"
			break
		case symptoms.count+1:
			self.dismiss(animated: true, completion: nil)
			break
		default:
			mainTextView.text = "\(symptoms[currentState])?"
			break
		}
		currentState += 1
	}
	
}
