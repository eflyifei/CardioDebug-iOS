//
//  CustomTabBarController.swift
//  ImproveHRV
//
//  Created by Arefly on 1/13/17.
//  Copyright © 2017 Arefly. All rights reserved.
//

import UIKit
import Foundation

// TODO: its not vertically center on iPad?
class CustomTabBarController: UITabBarController, UITabBarControllerDelegate {
	override func viewDidLoad() {
		self.delegate = self
	}
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	/*
	// http://stackoverflow.com/a/29011197/2603230
	override func viewWillLayoutSubviews() {
	var tabFrame = self.tabBar.frame
	// - 45 is editable , the default value is 49 px, below lowers the tabbar and above increases the tab bar size
	tabFrame.size.height = 45
	tabFrame.origin.y = self.view.frame.size.height - 45
	self.tabBar.frame = tabFrame
	}*/
	func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
		if viewController.restorationIdentifier == "NewButtonHolderView" {
			print("selected NewButtonHolderView")
			self.performSegue(withIdentifier: AddNewDataViewController.PRESENT_ADD_DATA_VIEW, sender: self)
			return false
		}
		return true
	}
}
