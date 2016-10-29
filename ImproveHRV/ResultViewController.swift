//
//  ResultViewController.swift
//  ImproveHRV
//
//  Created by Jason Ho on 23/10/2016.
//  Copyright © 2016 Arefly. All rights reserved.
//

import UIKit
import Charts
import Surge

class ResultViewController: UIViewController {
	static let SHOW_RESULT_SEGUE_ID = "showResult"

	@IBOutlet var resultLabel: UILabel!
	@IBOutlet var chartView: LineChartView!
	@IBOutlet var debugTextView: UITextView!

	var rawData: [Int]!


	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let _ = rawData {
			if !rawData.isEmpty {
				if rawData.count >= 10*100 {
					initChart()
					getHRVData(values: rawData)
				} else {
					print("time too short!")
				}
			}
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


	func initChart() {

		/*
		圖標註釋：
		X軸：檢查站ID
		Y軸：從當次開始練習到該檢查站的總時間
		故圖標數值將只會永遠向上、不會減少
		*/



		chartView.noDataText = "No chart data available."
		//chartView.chartDescription.text = "Use your fingers to zoom in or out!"
		chartView.pinchZoomEnabled = false           // 不允許手指同時放大XY兩軸
		chartView.animate(xAxisDuration: 1.0)       // 從下往上動態載入圖表


		let rightAxis = chartView.rightAxis         // 右側Y軸
		rightAxis.drawLabelsEnabled = false         // 不顯示右側Y軸
		rightAxis.drawGridLinesEnabled = false


		let leftAxis = chartView.leftAxis           // 左側Y軸
		leftAxis.drawLabelsEnabled = false
		leftAxis.drawAxisLineEnabled = false         // 不顯示軸
		leftAxis.drawGridLinesEnabled = false


		let xAxis = chartView.xAxis                 // X軸
		xAxis.drawAxisLineEnabled = true            // 顯示軸
		xAxis.drawGridLinesEnabled = false          // 不於圖表內顯示縱軸線
		xAxis.labelPosition = .bottom
		//xAxis.setLabelsToSkip(0)                    // X軸不隱藏任何值（見文檔）


		let values = rawData
		var dataEntries: [ChartDataEntry] = []
		for (index, value) in (values?.enumerated())! {
			let dataEntry = ChartDataEntry(x: Double(index), y: Double(value))
			dataEntries.append(dataEntry)
		}

		let allAverageTimeDataSet = LineChartDataSet(values: dataEntries, label: "Average Time among all")
		allAverageTimeDataSet.colors = [UIColor.lightGray]
		//allAverageTimeDataSet.fillColor = UIColor.lightGray
		allAverageTimeDataSet.drawCirclesEnabled = false
		//allAverageTimeDataSet.drawFilledEnabled = true





		// 設定X軸底部內容
		let checkpointsName: [String] = ["haha", "55", "no"]
		let lineChartData = LineChartData(dataSets: [allAverageTimeDataSet])
		chartView.data = lineChartData
	}


	func getHRVData(values: [Int]) {
		print("values count: \(values.count)")

		var slopes: [Float] = [0, 0]
		var importantSlopes: [Int] = []

		for (no, value) in values.enumerated() {
			if no > 2 && no < values.count-2 {
				let slope = getSlope(n: no, values: values)
				//print(slope)
				slopes.append(slope)
			}
		}

		let firstMaxI = slopes.prefix(through: 100).max()
		print("firstMaxI: \(firstMaxI)")

		let slope_threshold = (4.0/16.0)*firstMaxI!
		print(slope_threshold)


		for (no, value) in values.enumerated() {
			if no > 2 && no < values.count-1-2-1 {
				let slope = slopes[no]
				let anotherSlope = slopes[no+1]
				if (slope > slope_threshold) && (anotherSlope > slope_threshold) {
					print("importantSlopes append \(no) = \(value)")
					importantSlopes.append(no)
					//break
				}
			}
		}
		importantSlopes.append(importantSlopes[importantSlopes.count-1]+1)
		importantSlopes.append(importantSlopes[importantSlopes.count-1]+10)


		var mostImportantSlopes = [Int]()
		for (no, importantSlope) in importantSlopes.enumerated() {
			if no < importantSlopes.count-1-1 {
				let nextSlope = importantSlopes[no+1]
				let doubleNSlope = importantSlopes[no+2]
				if (nextSlope <= importantSlope+10) && (doubleNSlope > importantSlope+10) {
					print("mostImportantSlopes append \(importantSlope)")
					mostImportantSlopes.append(importantSlope)
				} else {
					print("ignore \(importantSlope)")
				}
			}
		}
		print("mostImportantSlopes: \(mostImportantSlopes)")


		var allMaxRIndex = [Int]()
		for (no, mostImportantSlope) in mostImportantSlopes.enumerated() {


			var startRange = 0
			if (mostImportantSlope-40) > 0 {
				startRange = mostImportantSlope-40
			}

			var endRange = values.count-1
			if (mostImportantSlope+40) < (values.count-1) {
				endRange = mostImportantSlope+40
			}


			let firstMaxRRange = values[startRange..<endRange]
			let firstMinQRange = values[startRange..<endRange]


			let firstMaxR = firstMaxRRange.max()
			let firstMinQ = firstMinQRange.min()

			let firstMaxRIndex = firstMaxRRange.index(of: firstMaxR!)
			let firstMaxQIndex = firstMinQRange.index(of: firstMinQ!)

			allMaxRIndex.append(firstMaxRIndex!)

			print("firstMaxRIndex: \(firstMaxRIndex)")
			print("firstMaxQIndex: \(firstMaxQIndex)")
			print("****")
		}

		print("----")
		print("allMaxRIndex: \(allMaxRIndex)")



		var RRDurations = [Float]()
		for (no, maxRIndex) in allMaxRIndex.enumerated() {
			if no < allMaxRIndex.count-1 {
				let duration = allMaxRIndex[no+1]-maxRIndex
				if duration > 10 {
					RRDurations.append(Float(duration))
				} else {
					print("WARNNING !!!!!! LESS THAN 0.1s!!!")
				}
			}
		}
		print("----")
		print("RRDurations: \(RRDurations)")


		debugTextView.text = "allMaxRIndex: \(allMaxRIndex)\nRRDurations: \(RRDurations)"




		let RRMean: Float = Surge.mean(RRDurations)
		print("RRMean: \(RRMean)")
		resultLabel.text = "RRMean: \(RRMean)"



		var sumInOneMin: Float = 0
		var beatsSumInOneMin: Int = 0
		var beatsEveryMin = [Int]()

		var RRAndMeanRRDiffs = [Float]()
		var RRAndNextRRDiffs = [Float]()
		var RRNextRRAndMeanRRNextRRDiffs = [Float]()
		for (index, eachDuration) in RRDurations.enumerated() {
			RRAndMeanRRDiffs.append(eachDuration-RRMean)

			if index < (RRDurations.count-1) {
				RRAndNextRRDiffs.append(RRDurations[index+1]-eachDuration)

				RRNextRRAndMeanRRNextRRDiffs.append((eachDuration-RRDurations[index+1])-(RRMean-eachDuration))
			}

			if sumInOneMin < 60*100 {
				sumInOneMin += eachDuration
				beatsSumInOneMin += 1
			} else {
				beatsEveryMin.append(beatsSumInOneMin)
				sumInOneMin = 60*100-sumInOneMin
				beatsSumInOneMin = 0
			}
		}

		// REMEMBER THIS VALUE NEED TO *10 TO BE RESULT IN MILISECONDS
		let SDNN: Float = Surge.sqrt(Surge.measq(RRAndMeanRRDiffs))
		print("SDNN: \(SDNN)")

		let rMSSD: Float = Surge.sqrt(Surge.measq(RRAndNextRRDiffs))
		print("rMSSD: \(rMSSD)")

		let SDSD: Float = Surge.sqrt(Surge.measq(RRNextRRAndMeanRRNextRRDiffs))
		print("SDSD: \(SDSD)")


		print("beatsEveryMin: \(beatsEveryMin)")



		let FFTTest: [Float] = Surge.fft(rawData.map{ Float($0) })
		print("FFTTest: \(FFTTest)")

		let dataAverage: Float = Surge.mean(rawData.map{ Float($0) })
		let FFTTestNEW: [Float] = Surge.fft(rawData.map{ Float($0)-dataAverage })
		print("FFTTestNEW: \(FFTTestNEW)")
	}

	func getSlope(n: Int, values: [Int]) -> Float {
		let one = Float(-2*values[n-2])
		let two = Float(values[n-1])
		let three = Float(values[n+1])
		let four = Float(2*values[n+2])
		
		return one-two+three+four
	}
	
}
