//
//  HistoryViewController.swift
//  ImproveHRV
//
//  Created by Jason Ho on 31/10/2016.
//  Copyright © 2016 Arefly. All rights reserved.
//

import UIKit
import Foundation
import Async
import Charts
import RealmSwift

class HistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

	@IBOutlet var tableView: UITableView!
	@IBOutlet var chartView: LineChartView!

	var refreshControl: UIRefreshControl!

	var realm: Realm!

	var tableData: [ECGData]!

	let cellID = "HistoryCell"
	var tagIDs: [String: Int] = [:]               // 謹記不能為0（否則於cell.tag重複）或小於100（可能於其後cell.tag設置後重複）
	var viewWidths: [String: CGFloat] = [:]
	var viewPaddings: [String: CGFloat] = [:]
	var outerViewPaddings: [String: CGFloat] = [:]

	// MARK: - override func
	override func viewDidLoad() {
		super.viewDidLoad()

		if let navController = self.navigationController {
			// http://stackoverflow.com/a/18969325/2603230
			navController.navigationBar.setBackgroundImage(UIImage(), for: .default)
			navController.navigationBar.shadowImage = UIImage()
			navController.navigationBar.isTranslucent = true
			navController.navigationBar.tintColor = StoredColor.middleBlue
		}


		tableView.delegate = self
		tableView.dataSource = self

		realm = try! Realm()

		tableData = []


		refreshControl = UIRefreshControl()
		refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
		refreshControl.addTarget(self, action: #selector(self.refreshData), for: UIControlEvents.valueChanged)
		self.tableView.addSubview(refreshControl)
		self.tableView.sendSubview(toBack: refreshControl)


		self.navigationItem.title = "History"
		self.navigationItem.rightBarButtonItem = self.editButtonItem

		let shareAction = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.shareRecords))
		self.navigationItem.setLeftBarButton(shareAction, animated: true)


		tagIDs["leftView"] = 101
		tagIDs["leftmostImageView"] = 110
		tagIDs["rightView"] = 201
		tagIDs["upperLeftLabel"] = 210
		tagIDs["lowerLeftLabel"] = 211
		tagIDs["upperRightLabel"] = 221

		viewWidths["leftView"] = 45.0

		viewPaddings["leftmostImageView"] = 10.0

		outerViewPaddings["left"] = 10.0
		outerViewPaddings["right"] = 0.0
		outerViewPaddings["top"] = 10.0
		outerViewPaddings["bottom"] = 10.0
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		print("RecordViewController viewWillAppear")

		refreshData()
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == ResultViewController.SHOW_RESULT_SEGUE_ID {
			if let destination = segue.destination as? ResultViewController {
				if let indexPath: IndexPath = self.tableView.indexPathForSelectedRow {
					let data = tableData[indexPath.row]

					let passedData = PassECGResult()
					passedData.startDate = data.startDate
					passedData.rawData = data.rawData
					passedData.isNew = false

					destination.passedData = passedData


					self.tableView.deselectRow(at: indexPath, animated: true)
				}
			}
		}
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)
		self.tableView.setEditing(editing, animated: animated)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func refreshData() {
		let allECGData = realm.objects(ECGData.self).sorted(byProperty: "startDate", ascending: false)
		//print(allECGData)

		tableData = Array(allECGData)

		self.tableView.reloadSections(NSIndexSet(index: 0) as IndexSet, with: .automatic)

		if refreshControl.isRefreshing {
			HelperFunctions.delay(1.0) {
				self.refreshControl.endRefreshing()
			}
		}

		if !tableData.isEmpty {
			Async.main {
				self.initChart()
			}
		}
	}


	func initChart() {

		chartView.noDataText = "No chart data available."
		chartView.chartDescription?.text = ""
		chartView.pinchZoomEnabled = false
		//chartView.animate(xAxisDuration: 1.0)


		let rightAxis = chartView.rightAxis
		rightAxis.drawLabelsEnabled = false
		rightAxis.drawAxisLineEnabled = false
		rightAxis.drawGridLinesEnabled = false


		let leftAxis = chartView.leftAxis
		leftAxis.drawLabelsEnabled = false
		leftAxis.drawAxisLineEnabled = false
		leftAxis.drawGridLinesEnabled = false


		let xAxis = chartView.xAxis
		xAxis.drawAxisLineEnabled = false
		xAxis.drawGridLinesEnabled = false
		xAxis.labelPosition = .bottom
		xAxis.valueFormatter = ChartDateToStringFormatter()
		xAxis.setLabelCount(3, force: true)


		var userSDNNDataEntries: [ChartDataEntry] = []
		var userLFHFDataEntries: [ChartDataEntry] = []
		var userAVNNDataEntries: [ChartDataEntry] = []

		var LFHFUpperLimitDataEntries: [ChartDataEntry] = []
		var LFHFLowerLimitDataEntries: [ChartDataEntry] = []

		var AVNNUpperLimitDataEntries: [ChartDataEntry] = []
		var AVNNLowerLimitDataEntries: [ChartDataEntry] = []

		if let _ = tableData {
			let values = tableData.reversed()
			for (_, value) in values.enumerated() {
				let time = Double(value.startDate.timeIntervalSinceReferenceDate)

				let LFHFUpperLimitDataEntry = ChartDataEntry(x: time, y: 5)
				LFHFUpperLimitDataEntries.append(LFHFUpperLimitDataEntry)
				let LFHFLowerLimitDataEntry = ChartDataEntry(x: time, y: 2)
				LFHFLowerLimitDataEntries.append(LFHFLowerLimitDataEntry)

				let AVNNUpperLimitDataEntry = ChartDataEntry(x: time, y: 859)
				AVNNUpperLimitDataEntries.append(AVNNUpperLimitDataEntry)
				let AVNNLowerLimitDataEntry = ChartDataEntry(x: time, y: 818)
				AVNNLowerLimitDataEntries.append(AVNNLowerLimitDataEntry)

				if let SDNN = value.result["SDNN"] {
					print("SDNN: \(SDNN) time: \(time)")
					let userSDNNDataEntry = ChartDataEntry(x: time, y: SDNN)
					userSDNNDataEntries.append(userSDNNDataEntry)
				}
				if let LFHF = value.result["LF/HF"] {
					print("LFHF: \(LFHF) time: \(time)")
					let userLFHFDataEntry = ChartDataEntry(x: time, y: LFHF)
					userLFHFDataEntries.append(userLFHFDataEntry)
				}
				if let AVNN = value.result["AVNN"] {
					print("AVNN: \(AVNN) time: \(time)")
					let userAVNNDataEntry = ChartDataEntry(x: time, y: AVNN)
					userAVNNDataEntries.append(userAVNNDataEntry)
				}
			}
		}

		/*let userSDNNDataSet = LineChartDataSet(values: userSDNNDataEntries, label: "Your SDNN")
		userSDNNDataSet.colors = [UIColor.gray]
		userSDNNDataSet.drawCirclesEnabled = false*/

		let userLFHFDataSet = LineChartDataSet(values: userLFHFDataEntries, label: "Your LF/HF")
		userLFHFDataSet.axisDependency = .left
		userLFHFDataSet.colors = [StoredColor.middleBlue]
		userLFHFDataSet.drawCirclesEnabled = true
		userLFHFDataSet.circleRadius = 5
		userLFHFDataSet.circleColors = [StoredColor.middleBlue]
		userLFHFDataSet.mode = .cubicBezier
		userLFHFDataSet.lineWidth = 2.0
		//userLFHFDataSet.highlightColor = UIColor.red
		userLFHFDataSet.highlightEnabled = false

		let userAVNNDataSet = LineChartDataSet(values: userAVNNDataEntries, label: "Your AVNN")
		userAVNNDataSet.axisDependency = .right
		userAVNNDataSet.colors = [StoredColor.darkRed]
		userAVNNDataSet.drawCirclesEnabled = true
		userAVNNDataSet.circleRadius = 5
		userAVNNDataSet.circleColors = [StoredColor.darkRed]
		userAVNNDataSet.mode = .cubicBezier
		userAVNNDataSet.lineWidth = 2.0
		userAVNNDataSet.highlightColor = UIColor.blue
		userAVNNDataSet.highlightEnabled = false


		let LFHFUpperLimitDataSet = LineChartDataSet(values: LFHFUpperLimitDataEntries, label: "")
		LFHFUpperLimitDataSet.axisDependency = .left
		LFHFUpperLimitDataSet.colors = [StoredColor.middleBlue.withAlphaComponent(0.3)]
		LFHFUpperLimitDataSet.drawValuesEnabled = false
		LFHFUpperLimitDataSet.drawCirclesEnabled = false
		LFHFUpperLimitDataSet.mode = .linear
		LFHFUpperLimitDataSet.lineWidth = 0.5
		LFHFUpperLimitDataSet.highlightEnabled = false
		/*LFHFUpperLimitDataSet.fillAlpha = 0.1
		LFHFUpperLimitDataSet.fillColor = StoredColor.middleBlue
		LFHFUpperLimitDataSet.drawFilledEnabled = true*/

		let LFHFLowerLimitDataSet = LineChartDataSet(values: LFHFLowerLimitDataEntries, label: "")
		LFHFLowerLimitDataSet.axisDependency = .left
		LFHFLowerLimitDataSet.colors = [StoredColor.middleBlue.withAlphaComponent(0.3)]
		LFHFLowerLimitDataSet.drawValuesEnabled = false
		LFHFLowerLimitDataSet.drawCirclesEnabled = false
		LFHFLowerLimitDataSet.mode = .linear
		LFHFLowerLimitDataSet.lineWidth = 0.5
		LFHFLowerLimitDataSet.highlightEnabled = false
		/*LFHFLowerLimitDataSet.fillAlpha = 1.0
		LFHFLowerLimitDataSet.fillColor = UIColor.white
		LFHFLowerLimitDataSet.drawFilledEnabled = true*/

		let AVNNUpperLimitDataSet = LineChartDataSet(values: AVNNUpperLimitDataEntries, label: "")
		AVNNUpperLimitDataSet.axisDependency = .right
		AVNNUpperLimitDataSet.colors = [StoredColor.darkRed.withAlphaComponent(0.3)]
		AVNNUpperLimitDataSet.drawValuesEnabled = false
		AVNNUpperLimitDataSet.drawCirclesEnabled = false
		AVNNUpperLimitDataSet.mode = .linear
		AVNNUpperLimitDataSet.lineWidth = 0.5
		AVNNUpperLimitDataSet.highlightEnabled = false
		//AVNNUpperLimitDataSet.fillAlpha = 0.1
		//AVNNUpperLimitDataSet.fillColor = StoredColor.darkRed
		//AVNNUpperLimitDataSet.drawFilledEnabled = true

		let AVNNLowerLimitDataSet = LineChartDataSet(values: AVNNLowerLimitDataEntries, label: "")
		AVNNLowerLimitDataSet.axisDependency = .right
		AVNNLowerLimitDataSet.colors = [StoredColor.darkRed.withAlphaComponent(0.3)]
		AVNNLowerLimitDataSet.drawValuesEnabled = false
		AVNNLowerLimitDataSet.drawCirclesEnabled = false
		AVNNLowerLimitDataSet.mode = .linear
		AVNNLowerLimitDataSet.lineWidth = 0.5
		AVNNLowerLimitDataSet.highlightEnabled = false
		//AVNNLowerLimitDataSet.fillAlpha = 1.0
		//AVNNLowerLimitDataSet.fillColor = UIColor.white
		//AVNNLowerLimitDataSet.drawFilledEnabled = true

		let lineChartData = LineChartData(dataSets: [userLFHFDataSet, userAVNNDataSet, LFHFUpperLimitDataSet, LFHFLowerLimitDataSet, AVNNUpperLimitDataSet, AVNNLowerLimitDataSet])
		chartView.data = lineChartData
	}


	func shareRecords() {
		let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

		let fileName = NSURL(fileURLWithPath: documentsPath).appendingPathComponent("default.realm")
		if let filePath = fileName?.path {
			let fileManager = FileManager.default
			if fileManager.fileExists(atPath: filePath) {
				let fileData = NSURL(fileURLWithPath: filePath)

				let objectsToShare = [fileData]
				let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

				if let popoverVC = activityVC.popoverPresentationController {
					popoverVC.barButtonItem = self.navigationItem.leftBarButtonItem
				}
				self.present(activityVC, animated: true, completion: nil)
			}
		}
	}


	// MARK: - tableView related
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return tableData.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		/*** 初始化TableCell開始 ***/
		var cell: UITableViewCell!

		var leftView: UIView!
		var leftmostImageView: UIImageView!

		var rightView: UIView!
		var upperLeftLabel: PaddingLabel!
		var lowerLeftLabel: PaddingLabel!
		var upperRightLabel: PaddingLabel!


		if let reuseCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
			print("目前Cell \(indexPath.row)已創建過，即將dequeue這個cell")
			cell = reuseCell

			leftView = cell?.contentView.viewWithTag(tagIDs["leftView"]!)
			leftmostImageView = cell?.contentView.viewWithTag(tagIDs["leftmostImageView"]!) as! UIImageView

			rightView = cell?.contentView.viewWithTag(tagIDs["rightView"]!)
			lowerLeftLabel = cell?.contentView.viewWithTag(tagIDs["lowerLeftLabel"]!) as! PaddingLabel
			upperLeftLabel = cell?.contentView.viewWithTag(tagIDs["upperLeftLabel"]!) as! PaddingLabel
			upperRightLabel = cell?.contentView.viewWithTag(tagIDs["upperRightLabel"]!) as! PaddingLabel
		} else {
			print("目前Cell \(indexPath.row)為nil，即將創建新Cell")

			cell = UITableViewCell(style: .default, reuseIdentifier: cellID)
			let contentView = cell.contentView

			// use addConstraint instead of addConstraints because Swift compile it faster


			/** leftView 開始 **/
			leftView = UIView()
			leftView.tag = tagIDs["leftView"]!
			leftView.backgroundColor = UIColor.clear
			leftView.translatesAutoresizingMaskIntoConstraints = false
			contentView.insertSubview(leftView, at: 0)

			contentView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .leading, relatedBy: .equal, toItem: cell.contentView, attribute: .leading, multiplier: 1.0, constant: outerViewPaddings["left"]!))
			contentView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1.0, constant: outerViewPaddings["top"]!))
			contentView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1.0, constant: -outerViewPaddings["bottom"]!))
			contentView.addConstraint(NSLayoutConstraint(item: leftView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1.0, constant: viewWidths["leftView"]!))            // 寬度=numberLabel+timelineView的寬度


			/** leftmostImageView 開始 **/
			leftmostImageView = UIImageView()
			leftmostImageView.tag = tagIDs["leftmostImageView"]!
			leftmostImageView.translatesAutoresizingMaskIntoConstraints = false
			leftView.addSubview(leftmostImageView)

			contentView.addConstraint(NSLayoutConstraint(item: leftmostImageView, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: .leading, multiplier: 1.0, constant: viewPaddings["leftmostImageView"]!))
			contentView.addConstraint(NSLayoutConstraint(item: leftmostImageView, attribute: .trailing, relatedBy: .equal, toItem: leftView, attribute: .trailing, multiplier: 1.0, constant: -viewPaddings["leftmostImageView"]!))
			contentView.addConstraint(NSLayoutConstraint(item: leftmostImageView, attribute: .height, relatedBy: .equal, toItem: leftmostImageView, attribute: .width, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: leftmostImageView, attribute: .centerX, relatedBy: .equal, toItem: leftView, attribute: .centerX, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: leftmostImageView, attribute: .centerY, relatedBy: .equal, toItem: leftView, attribute: .centerY, multiplier: 1.0, constant: 0.0))


			/** rightView 開始 **/
			rightView = UIView()
			rightView.tag = tagIDs["rightView"]!
			rightView.backgroundColor = UIColor.clear
			rightView.translatesAutoresizingMaskIntoConstraints = false
			contentView.insertSubview(rightView, at: 0)

			contentView.addConstraint(NSLayoutConstraint(item: rightView, attribute: .leading, relatedBy: .equal, toItem: leftView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: rightView, attribute: .trailing, relatedBy: .equal, toItem: cell.contentView, attribute: .trailing, multiplier: 1.0, constant: -outerViewPaddings["right"]!))
			contentView.addConstraint(NSLayoutConstraint(item: rightView, attribute: .top, relatedBy: .equal, toItem: cell.contentView, attribute: .top, multiplier: 1.0, constant: outerViewPaddings["top"]!))
			contentView.addConstraint(NSLayoutConstraint(item: rightView, attribute: .bottom, relatedBy: .equal, toItem: cell.contentView, attribute: .bottom, multiplier: 1.0, constant: -outerViewPaddings["bottom"]!))


			/** upperLeftLabel 開始 **/
			upperLeftLabel = PaddingLabel()
			upperLeftLabel.tag = tagIDs["upperLeftLabel"]!
			upperLeftLabel.translatesAutoresizingMaskIntoConstraints = false
			rightView.addSubview(upperLeftLabel)

			contentView.addConstraint(NSLayoutConstraint(item: upperLeftLabel, attribute: .leading, relatedBy: .equal, toItem: rightView, attribute: .leading, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperLeftLabel, attribute: .top, relatedBy: .equal, toItem: rightView, attribute: .top, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperLeftLabel, attribute: .height, relatedBy: .equal, toItem: rightView, attribute: .height, multiplier: 0.6, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperLeftLabel, attribute: .width, relatedBy: .equal, toItem: rightView, attribute: .width, multiplier: 0.5, constant: 0.0))


			/** lowerLeftLabel 開始 **/
			lowerLeftLabel = PaddingLabel()
			lowerLeftLabel.tag = tagIDs["lowerLeftLabel"]!
			lowerLeftLabel.translatesAutoresizingMaskIntoConstraints = false
			rightView.addSubview(lowerLeftLabel)

			contentView.addConstraint(NSLayoutConstraint(item: lowerLeftLabel, attribute: .leading, relatedBy: .equal, toItem: upperLeftLabel, attribute: .leading, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: lowerLeftLabel, attribute: .trailing, relatedBy: .equal, toItem: rightView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: lowerLeftLabel, attribute: .top, relatedBy: .equal, toItem: upperLeftLabel, attribute: .bottom, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: lowerLeftLabel, attribute: .bottom, relatedBy: .equal, toItem: rightView, attribute: .bottom, multiplier: 1.0, constant: 0.0))



			/** upperRightLabel 開始 **/
			upperRightLabel = PaddingLabel()
			upperRightLabel.tag = tagIDs["upperRightLabel"]!
			upperRightLabel.textAlignment = .right
			upperRightLabel.translatesAutoresizingMaskIntoConstraints = false
			rightView.addSubview(upperRightLabel)

			contentView.addConstraint(NSLayoutConstraint(item: upperRightLabel, attribute: .leading, relatedBy: .equal, toItem: upperLeftLabel, attribute: .trailing, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperRightLabel, attribute: .trailing, relatedBy: .equal, toItem: rightView, attribute: .trailing, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperRightLabel, attribute: .top, relatedBy: .equal, toItem: rightView, attribute: .top, multiplier: 1.0, constant: 0.0))
			contentView.addConstraint(NSLayoutConstraint(item: upperRightLabel, attribute: .height, relatedBy: .equal, toItem: upperLeftLabel, attribute: .height, multiplier: 1.0, constant: 0.0))



			/*
			leftmostImageView.backgroundColor = UIColor.brown
			upperLeftLabel.backgroundColor = UIColor.purple
			lowerLeftLabel.backgroundColor = UIColor.orange
			upperRightLabel.backgroundColor = UIColor.yellow
			*/

		}

		cell.accessoryType = .disclosureIndicator
		cell.separatorInset = UIEdgeInsetsMake(0, outerViewPaddings["left"]!+viewWidths["leftView"]!+PaddingLabel.padding, 0, 0)

		/*** 初始化TableCell結束 ***/



		/*** 修改數據開始 ***/
		let section = indexPath.section
		let row = indexPath.row
		cell.tag = section*1000 + row


		let result = tableData[row].result
		var cellText = "[...]"
		if !result.isEmpty {
			if let LFHF = result["LF/HF"] {
				cellText = "LF/HF: \(String(format:"%.2f", LFHF))"
			}
		}


		if let iconImage = UIImage(named: "CellIcon-ECG") {
			leftmostImageView.image = iconImage
		}


		upperLeftLabel.textColor = StoredColor.middleBlue
		upperLeftLabel.font = UIFont(name: (upperLeftLabel.font?.fontName)!, size: 20.0)
		lowerLeftLabel.textColor = UIColor(netHex: 0x8e9092)
		upperRightLabel.font = UIFont(name: (upperRightLabel.font?.fontName)!, size: 20.0)


		upperLeftLabel.text = cellText
		lowerLeftLabel.text = "\(DateFormatter.localizedString(from: tableData[indexPath.row].startDate, dateStyle: .short, timeStyle: .short))"
		upperRightLabel.text = "upperRightLabel"

		/*** 修改數據結束 ***/

		return cell
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 50.0+outerViewPaddings["top"]!+outerViewPaddings["bottom"]!
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		self.performSegue(withIdentifier: ResultViewController.SHOW_RESULT_SEGUE_ID, sender: self)
		self.tableView.deselectRow(at: indexPath, animated: true)
	}

	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return false
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		if (editingStyle == .delete) {
			try! realm.write {
				realm.delete(tableData[indexPath.row])
			}
			tableData.remove(at: indexPath.row)
			tableView.deleteRows(at: [indexPath], with: .automatic)

			initChart()
		}
	}
}

class ChartDateToStringFormatter: NSObject, IAxisValueFormatter {
	public func stringForValue(_ value: Double, axis: AxisBase?) -> String {
		let formatter = DateFormatter()
		formatter.dateFormat = "dd-MM-yyyy HH:mm"
		let date = Date(timeIntervalSinceReferenceDate: TimeInterval(value))
		return formatter.string(from: date)
	}
}
