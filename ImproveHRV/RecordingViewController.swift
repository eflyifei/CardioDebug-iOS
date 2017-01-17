//
//  RecordingViewController.swift
//  ImproveHRV
//
//  Created by Jason Ho on 21/10/2016.
//  Copyright © 2016 Arefly. All rights reserved.
//

import UIKit
import CoreBluetooth
import Async
import BITalinoBLE
import Charts

enum DeviceType {
	case ble
	case bitalino
}

class RecordingViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, BITalinoBLEDelegate {

	// MARK: - static var
	static let DEFAULTS_BLE_DEVICE_NAME = "bleDeviceName"

	// MARK: - basic var
	let application = UIApplication.shared
	let defaults = UserDefaults.standard

	fileprivate typealias `Self` = RecordingViewController

	// MARK: - IBOutlet var
	@IBOutlet var outerProgressCircleView: UIView!

	@IBOutlet var mainLabel: UILabel!
	@IBOutlet var upperLabel: UILabel!

	@IBOutlet var chartView: LineChartView!

	// MARK: - init var
	var progressCircleView: ProgressCircleView!

	var manager: CBCentralManager!
	var peripheral: CBPeripheral!

	var bitalino: BITalinoBLE!

	var timer: Timer!
	var startTime: Date!
	var endTime: Date!
	var duration: TimeInterval!

	var currentState: Int = 0

	var isConnectedAndRecording: Bool!

	// MARK: - data var
	var rawData: [Int]!

	var deviceType: DeviceType!


	let frequency: Int = 100

	let extraPreTime: TimeInterval = 15.0

	let BITALINO_DEVICE_UUID = "1AC1F712-C6FE-4728-9BEF-DBD2A6177D47"



	// MARK: - override func
	override func viewDidLoad() {
		super.viewDidLoad()



		self.navigationItem.title = ""




		rawData = []

		deviceType = .ble



		manager = CBCentralManager(delegate: self, queue: nil)

		bitalino = BITalinoBLE.init(uuid: BITALINO_DEVICE_UUID)
		bitalino.delegate = self



		mainLabel.alpha = 0.0
		mainLabel.textColor = getElementColor()

		upperLabel.alpha = 0.0
		upperLabel.textColor = getElementColor()


		Async.main {
			self.adjustFontSize()
		}


		isConnectedAndRecording = false


		currentState = 0



		Async.main {
			self.progressCircleView = ProgressCircleView(circleColor: StoredColor.darkRed)
			self.progressCircleView.translatesAutoresizingMaskIntoConstraints = false
			self.outerProgressCircleView.addSubview(self.progressCircleView)

			self.outerProgressCircleView.addConstraint(NSLayoutConstraint(item: self.progressCircleView, attribute: .leading, relatedBy: .equal, toItem: self.outerProgressCircleView, attribute: .leading, multiplier: 1.0, constant: 0))
			self.outerProgressCircleView.addConstraint(NSLayoutConstraint(item: self.progressCircleView, attribute: .top, relatedBy: .equal, toItem: self.outerProgressCircleView, attribute: .top, multiplier: 1.0, constant: 0))
			self.outerProgressCircleView.addConstraint(NSLayoutConstraint(item: self.progressCircleView, attribute: .bottom, relatedBy: .equal, toItem: self.outerProgressCircleView, attribute: .bottom, multiplier: 1.0, constant: 0))
			self.outerProgressCircleView.addConstraint(NSLayoutConstraint(item: self.progressCircleView, attribute: .trailing, relatedBy: .equal, toItem: self.outerProgressCircleView, attribute: .trailing, multiplier: 1.0, constant: 0))
			self.outerProgressCircleView.layoutIfNeeded()

			self.progressCircleView.setupCircle()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if bitalino.isConnected {
			if bitalino.isRecording {
				bitalino.stopRecording()
			}
			bitalino.disconnect()
		}
		isConnectedAndRecording = false


		enableButtons()

		mainLabel.text = "Unconnected"


		NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)

		initChart()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		Async.main {
			self.mainButtonAction()
		}
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		coordinator.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) -> Void in
			let orient = self.application.statusBarOrientation

			self.adjustFontSize()

			if UIDevice.current.userInterfaceIdiom == .phone {
				if UIInterfaceOrientationIsLandscape(orient) {
					// as the circle is too big to display
					self.progressCircleView.isHidden = true
				} else {
					self.progressCircleView.isHidden = false
				}
			}

			self.progressCircleView.progressCircle.removeFromSuperlayer()
			self.progressCircleView.setupCircle()
			self.progressCircleView.startAnimation(duration: self.endTime.timeIntervalSinceNow, fromValue: Double(1)-(self.endTime.timeIntervalSinceNow/self.duration))

			self.view.layoutIfNeeded()

		}, completion: { (UIViewControllerTransitionCoordinatorContext) -> Void in
			// Finish Transition
		})

		super.viewWillTransition(to: size, with: coordinator)
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == ResultViewController.SHOW_RESULT_SEGUE_ID {
			if let destinationNavigationController = segue.destination as? UINavigationController {
				if let destination = destinationNavigationController.topViewController as? ResultViewController {

					#if DEBUG
						if DebugConfig.skipRecordingAndGetResultDirectly == true {
							if let debugRawData = DebugConfig.getDebugECGRawData() {
								rawData = debugRawData
							} else {
								fatalError("ERROR in getting debugRawData!")
							}
						}
					#endif

					let passedData = PassECGResult()
					passedData.startDate = (startTime ?? Date()).addingTimeInterval(extraPreTime)
					let extraPreTimeDataCount = Int(extraPreTime)*frequency
					if rawData.count-1 > extraPreTimeDataCount {
						rawData.removeSubrange(0...extraPreTimeDataCount)
					}
					print(rawData.description)
					passedData.rawData = rawData
					passedData.isNew = true

					destination.passedData = passedData

					destination.passedBackData = { bool in
						print("ResultViewController passedBackData \(bool)")
						if bool == true {
							Async.main(after: 0.5) {
								self.mainButtonAction()
							}
						}
					}

				}
			}
		}
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}


	// MARK: - app life cycle related func
	func didEnterBackground() {
		print("didEnterBackground()")
		stopTimer()
		setupViewAndStopRecording(isNormalCondition: false)
		if isConnectedAndRecording == true {
			bitalino.stopRecording()
			print("isConnectedAndRecording true")
			//bitalino.disconnect()
		}
	}


	// MARK: - UI related func
	func initChart() {
		chartView.setViewPortOffsets(left: 0.0, top: 20.0, right: 0.0, bottom: 20.0)

		chartView.isUserInteractionEnabled = false
		chartView.noDataText = "No chart data available."
		chartView.chartDescription?.text = ""
		chartView.scaleXEnabled = false
		chartView.scaleYEnabled = false
		chartView.legend.enabled = false


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
		xAxis.drawLabelsEnabled = false		// 避免頭暈（太快了）
		//xAxis.labelPosition = .bottom
		//xAxis.valueFormatter = ChartCSDoubleToSecondsStringFormatter()

		// TODO: crash here?
		let ecgRawDataSet = LineChartDataSet(values: [ChartDataEntry](), label: nil)
		ecgRawDataSet.colors = [StoredColor.middleBlue]
		//ecgRawDataSet.mode = .cubicBezier			// commented as performance issue
		ecgRawDataSet.drawCirclesEnabled = false

		let lineChartData = LineChartData(dataSets: [ecgRawDataSet])
		lineChartData.setDrawValues(false)

		chartView.data = lineChartData
		chartView.data?.highlightEnabled = false
	}



	func mainButtonAction() {
		if currentState < 3 {
			currentState += 1
			#if DEBUG
				if DebugConfig.skipRecordingAndGetResultDirectly == true {
					self.performSegue(withIdentifier: ResultViewController.SHOW_RESULT_SEGUE_ID, sender: self)
					return
				}
			#endif
			setupViewAndStartConnect()
		} else {
			currentState = 0
			self.enableButtons()
			_ = self.navigationController?.popViewController(animated: true)
		}
	}


	func adjustFontSize() {
		print("adjustFontSize()")
		let screenSize: CGRect = UIScreen.main.bounds

		var basicFontSizeBasedOnScreenHeight = screenSize.height
		if UIDevice.current.userInterfaceIdiom == .phone {
			if UIDeviceOrientationIsLandscape(UIDevice.current.orientation) {
				// Value is based on test
				basicFontSizeBasedOnScreenHeight = basicFontSizeBasedOnScreenHeight * 1.7
			}
			if HelperFunctions.getInchFromWidth() == 3.5 {
				if UIDeviceOrientationIsPortrait(UIDevice.current.orientation) {
					// Value is based on test
					basicFontSizeBasedOnScreenHeight = basicFontSizeBasedOnScreenHeight * 1.3
				}
			}
		}
		if UIDevice.current.userInterfaceIdiom == .pad {
			if UIDeviceOrientationIsPortrait(UIDevice.current.orientation) {
				// Value is based on test
				basicFontSizeBasedOnScreenHeight = basicFontSizeBasedOnScreenHeight * 0.8
			}
		}

		mainLabel.font = UIFont(name: (mainLabel.font?.fontName)!, size: basicFontSizeBasedOnScreenHeight*0.09)
		upperLabel.font = UIFont(name: (mainLabel.font?.fontName)!, size: basicFontSizeBasedOnScreenHeight*0.045)
		upperLabel.textColor = StoredColor.middleBlue
	}

	/*func adjustAppropriateMainButtonOuterViewHeightConstraintConstantToSmallSize() {
		print("adjustAppropriateMainButtonOuterViewHeightConstraintConstantToSmallSize()")
			var constantToBeSet: CGFloat = 0.0
			if UIDevice.current.userInterfaceIdiom == .phone {
				if UIDeviceOrientationIsLandscape(UIDevice.current.orientation) {
					// Value is based on test
					constantToBeSet = 25
				}
			}
			if UIDevice.current.userInterfaceIdiom == .pad {
				if UIDeviceOrientationIsPortrait(UIDevice.current.orientation) {
					// Value is based on test
					constantToBeSet = -25
				}
			}
			mainButtonOuterViewHeightConstraint.constant = constantToBeSet
	}*/


	func enableButtons() {
		self.navigationController?.navigationBar.isUserInteractionEnabled = true
		self.navigationController?.navigationBar.tintColor = self.view.window?.tintColor

		self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
	}

	func disableButtons() {
		self.navigationController?.navigationBar.isUserInteractionEnabled = false
		self.navigationController?.navigationBar.tintColor = UIColor.lightGray

		self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
	}

	func setupViewAndStartConnect() {
		print("setupViewAndStartConnect()")

		Async.main {
			self.disableButtons()

			self.view.layoutIfNeeded()

			self.view.setNeedsUpdateConstraints()
			UIView.animate(withDuration: 1.0, animations: {
				self.view.layoutIfNeeded()
			}, completion: { (complete: Bool) in
				self.startConnect()
				UIView.animate(withDuration: 1.0, animations: {
					self.mainLabel.alpha = 1.0
					self.upperLabel.alpha = 1.0
				}, completion: { (complete: Bool) in
					self.application.isIdleTimerDisabled = true
				})
			})
		}
	}

	func setupViewAndStopRecording(isNormalCondition: Bool) {
		print("setupViewAndStopRecording()")

		// Async main here to make sure the animation is shown
		Async.main {
			self.application.isIdleTimerDisabled = false

			UIView.animate(withDuration: 1.0, animations: {
				self.mainLabel.alpha = 0.0
				self.upperLabel.alpha = 0.0
			}, completion: { (complete: Bool) in

				// make sure that the labels are really transparent
				self.mainLabel.alpha = 0.0
				self.upperLabel.alpha = 0.0


				self.view.layoutIfNeeded()

				self.view.setNeedsUpdateConstraints()
				UIView.animate(withDuration: 1.0, animations: {
					self.view.layoutIfNeeded()
				}, completion: { (complete: Bool) in
					self.stopRecording(isNormalCondition: isNormalCondition)
				})

			})
		}
		
	}

	func startConnect() {
		if deviceType == .bitalino {
			if !bitalino.isConnected {
				mainLabel.text = "Connecting..."
				bitalino.scanAndConnect()
			}
		} else if deviceType == .ble {
			var poweredOn = false
			if #available(iOS 10.0, *) {
				if manager.state == CBManagerState.poweredOn {
					poweredOn = true
				}
			} else {
				if manager.centralManagerState == CBCentralManagerState.poweredOn {
					poweredOn = true
				}
			}
			if poweredOn {
				mainLabel.text = "Connecting..."
				manager.scanForPeripherals(withServices: nil, options: nil)
			} else {
				mainLabel.text = "Please enable BT"
				print("Bluetooth not available")
			}
		}
	}

	func startRecording() {
		var canRecord = true
		if deviceType == .bitalino {
			if !bitalino.isConnected || bitalino.isRecording {
				canRecord = false
			}
		}

		if canRecord {
			//self.mainLabel.text = "Recording..."

			isConnectedAndRecording = true


			timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.timerAction), userInfo: nil, repeats: true)
			startTime = Date()
			duration = TimeInterval(5*60)+extraPreTime
			#if DEBUG
				if let debugDuration = DebugConfig.debugRecordDuration {
					duration = debugDuration
				}
			#endif
			endTime = startTime.addingTimeInterval(duration)
			self.timerAction()		// 為避免延遲一秒才開始執行


			if deviceType == .bitalino {
				rawData = []
				bitalino.startRecording(fromAnalogChannels: [0, 1, 2, 3, 4, 5], withSampleRate: 100, numberOfSamples: 50, samplesCompletion: { (frame: BITalinoFrame?) -> Void in
					if let result = frame?.a1 {
						if result != 0 {
							print("\(result)")
							self.rawData.append(result)
						} else {
							print("0 SO SAD")
						}
					}
				})
			} else if deviceType == .ble {
				// done in didDiscoverCharacteristicsFor & didUpdateValueFor
			}

		}
	}

	func stopRecording(isNormalCondition: Bool) {
		isConnectedAndRecording = false

		if isNormalCondition {
			if deviceType == .bitalino {
				bitalino.stopRecording()
			} else if deviceType == .ble {
				manager.cancelPeripheralConnection(peripheral)
			}
			//self.mainLabel.text = "Finished"
			self.performSegue(withIdentifier: ResultViewController.SHOW_RESULT_SEGUE_ID, sender: self)
			self.initChart()		// TODO: crash here
		} else {
			HelperFunctions.showAlert(self, title: "Warning", message: "The device disconnected unexpectedly. Please try again  to record later.", completion: nil)
			_ = self.navigationController?.popViewController(animated: true)
			print("not NormalCondition")
		}

		self.enableButtons()
	}

	func timerAction() {
		let timeTill = endTime.timeIntervalSinceNow
		//print(timeTill)
		if timeTill <= 0 {
			self.stopTimer()
			self.setupViewAndStopRecording(isNormalCondition: true)
		} else {
			let (h, m, s) = HelperFunctions.secondsToHoursMinutesSeconds(Int(endTime.timeIntervalSinceNow))
			if h > 0 {
				mainLabel.text = String(format: "%d:%02d:%02d", h, m, s)
			} else {
				mainLabel.text = String(format: "%02d:%02d", m, s)
			}
		}
	}

	func stopTimer() {
		mainLabel.text = "00:00"
		if let _ = timer {
			timer?.invalidate()
			timer = nil
		}
	}


	// MARK: - BLE related func
	// Reference: http://cms.35g.tw/coding/藍牙-ble-corebluetooth-初探/
	//            http://www.kevinhoyt.com/2016/05/20/the-12-steps-of-bluetooth-swift/
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		/*if central.state == CBManagerState.poweredOn {
			central.scanForPeripherals(withServices: nil, options: nil)
		} else {
			print("Bluetooth not available")
		}*/
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		if let name = peripheral.name {
			if name == defaults.string(forKey: Self.DEFAULTS_BLE_DEVICE_NAME) {
				print("Found device \(peripheral.identifier.uuidString)")

				self.manager.stopScan()

				self.peripheral = peripheral
				self.peripheral.delegate = self

				self.manager.connect(peripheral, options: nil)
			}
		}
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		print("Connected to device \(peripheral.name)")
		peripheral.discoverServices(nil)
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
		print("Disconnected device \(peripheral.identifier.uuidString)")
		if isConnectedAndRecording == true {
			self.stopTimer()
			self.progressCircleView.progressCircle.removeFromSuperlayer()
			mainLabel.text = "Disconnected :("
			HelperFunctions.delay(1.0) {
				self.setupViewAndStopRecording(isNormalCondition: false)
			}
		}
	}


	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		print("didDiscoverServices")
		if let services = peripheral.services {
			print("Services count: \(peripheral.services?.count)")
			for service in services {
				// CBUUID see data in LightBlue
				if service.uuid == CBUUID(string: "FFE0") {
					peripheral.discoverCharacteristics(nil, for: service)
				}
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		print("didDiscoverCharacteristicsFor \(service.uuid)")
		for characteristic in service.characteristics! {
			print("each characteristic: \(characteristic.uuid)")
			// CBUUID see data in LightBlue
			if characteristic.uuid == CBUUID(string: "FFE1") {
				HelperFunctions.delay(1.0) {
					self.startRecording()
					self.rawData = []

					self.progressCircleView.startAnimation(duration: self.duration)

					peripheral.setNotifyValue(true, for: characteristic)
				}
			}
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
		//print("didUpdateValueFor \(characteristic.uuid)")
		if let value = characteristic.value {
			// http://stackoverflow.com/a/32894672/2603230
			if let utf8Data = String(data: value, encoding: String.Encoding.utf8) {
				//print(utf8Data)
				let someReceivedData = utf8Data.components(separatedBy: " ")
				for eachReceivedData in someReceivedData {
					if !eachReceivedData.isEmpty {
						if let eachReceivedDataInt = Int(eachReceivedData) {
							//print(eachReceivedDataInt)
							self.rawData.append(eachReceivedDataInt)

							let dataSet = self.chartView.data?.getDataSetByIndex(0)
							let index = (dataSet?.entryCount)!-1+1
							let value = eachReceivedDataInt
							print("\(index) \(value)")

							let chartEntry = ChartDataEntry(x: Double(index), y: Double(value))
							chartView.data?.addEntry(chartEntry, dataSetIndex: 0)
							chartView.data?.notifyDataChanged()
							chartView.notifyDataSetChanged()

							chartView.setVisibleXRange(minXRange: 600, maxXRange: 600)
							chartView.moveViewToX(Double((chartView.data?.entryCount)!))
						}
					}
				}
			}
		}
	}


	// MARK: - bitalino related func
	func bitalinoDidConnect(_ bitalino: BITalinoBLE!) {
		mainLabel.text = "Connected :)"
		print("Connected")
		HelperFunctions.delay(1.0) {
			self.startRecording()
		}
	}

	func bitalinoDidDisconnect(_ bitalino: BITalinoBLE!) {
		print("Disconnected")
		if isConnectedAndRecording == true {
			self.stopTimer()
			self.progressCircleView.progressCircle.removeFromSuperlayer()
			mainLabel.text = "Disconnected :("
			HelperFunctions.delay(1.0) {
				self.setupViewAndStopRecording(isNormalCondition: false)
			}
		}
		//mainLabel.text = "NO"
	}

	func bitalinoRecordingStarted(_ bitalino: BITalinoBLE!) {
		//print("Recording Started")
	}

	func bitalinoRecordingStopped(_ bitalino: BITalinoBLE!) {
		HelperFunctions.delay(1.0) {
			bitalino.disconnect()
		}
	}

	func bitalinoBatteryThresholdUpdated(_ bitalino: BITalinoBLE!) {
		//do
	}

	func bitalinoBatteryDigitalOutputsUpdated(_ bitalino: BITalinoBLE!) {
		//do
	}



	// MARK: - helper func
	func setBackgroundColorWithAnimation(_ color: UIColor, duration: TimeInterval = 0.2) {
		if self.view.backgroundColor != color {
			UIView.animate(withDuration: duration, animations: { () -> Void in
				self.view.backgroundColor = color
			})
		}
	}


	// MARK: - style func
	/*func getBackgroundColor() -> UIColor {
		//return UIColor(netHex: 0xC8FFC8)
		return UIColor.white
	}*/
	func getElementColor() -> UIColor {
		return UIColor.black
	}

	func getButtonBackgroundColor() -> UIColor {
		return UIColor(netHex: 0x1C1C1C)
	}
	func getButtonElementColor() -> UIColor {
		return UIColor.white
	}

	/*func getElementColorString() -> String {
		return "Black"
	}*/

}
