//
//  AppDelegate.swift
//  ImproveHRV
//
//  Created by Jason Ho on 21/10/2016.
//  Copyright © 2016 Arefly. All rights reserved.
//

import UIKit
import CoreData
import RealmSwift
#if DEBUG
	import TouchVisualizer
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	static let DEFAULTS_NOTIFICATION_REGISTERED = "notificationRegistered"


	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		UITabBar.appearance().barTintColor = UIColor.white
		UITabBar.appearance().isOpaque = false
		UITabBar.appearance().tintColor = StoredColor.middleBlue

		self.window?.tintColor = StoredColor.middleBlue

		#if DEBUG
			if DebugConfig.showTouchIndicator {
				Visualizer.start()
			}
		#endif

		let config = Realm.Configuration(
			// Set the new schema version. This must be greater than the previously used version (if you've never set a schema version before, the version is 0).
			schemaVersion: 7,

			// Set the block which will be called automatically when opening a Realm with a schema version lower than the one set above
			migrationBlock: { migration, oldSchemaVersion in
				// If we haven’t migrated anything yet, oldSchemaVersion == 0
				// 0->1: rename _backingRawData to _ecgRawData
				if (oldSchemaVersion < 1) {
					var needMigration = false
					let oldObjectSchema = migration.oldSchema.objectSchema
					if let objectSchemaIndex = oldObjectSchema.index(where: { $0.className == "ECGData" }) {
						if let _ = oldObjectSchema[objectSchemaIndex].properties.index(where: { $0.name == "_backingRawData" }) {
							// only do migration if old name "_backingRawData" exist (do so as first schemaVersion is not managed well, so no need this in future new schemaVersion)
							needMigration = true
							print("NEED MIGRATION!")
						}
					}
					if needMigration {
						migration.renameProperty(onType: ECGData.className(), from: "_backingRawData", to: "_ecgRawData")
					}
				}

				// 1->2: add _fftRawData
				if (oldSchemaVersion < 2) {
					migration.enumerateObjects(ofType: ECGData.className()) { oldObject, newObject in
						newObject!["_fftRawData"] = []
					}
				}

				// 2->3: rename _ecgRawData to _rawData and add _rrData & _recordType
				if (oldSchemaVersion < 3) {
					migration.renameProperty(onType: ECGData.className(), from: "_ecgRawData", to: "_rawData")
					migration.enumerateObjects(ofType: ECGData.className()) { oldObject, newObject in
						newObject!["_recordType"] = RecordType.ecg.rawValue
						newObject!["_rrData"] = []
					}
				}

				// 3->4: add recordingHertz
				if (oldSchemaVersion < 4) {
					migration.enumerateObjects(ofType: ECGData.className()) { oldObject, newObject in
						newObject!["recordingHertz"] = 100.0
					}
				}

				// 4->5: add note
				if (oldSchemaVersion < 5) {
					migration.enumerateObjects(ofType: ECGData.className()) { oldObject, newObject in
						newObject!["note"] = ""
					}
				}

				// 5->6: fix old bugs by setting a more accurate frequency
				if (oldSchemaVersion < 6) {
					migration.enumerateObjects(ofType: ECGData.className()) { oldObject, newObject in
						if let oldHertz = oldObject?["recordingHertz"] as? Double {
							if oldHertz == 100.0 {
								newObject!["recordingHertz"] = oldHertz*0.9
								if let oldDuration = oldObject?["duration"] as? Double {
									newObject!["duration"] = oldDuration/0.9
								}
							}
						}
					}
				}

				// 6->7: remove duration (change to direct calculation inside ECGData)
				if (oldSchemaVersion < 7) {
					// Realm will automatically detect new properties and removed properties
					// And will update the schema on disk automatically
				}
		})
		// Tell Realm to use this new configuration object for the default Realm
		Realm.Configuration.defaultConfiguration = config

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

}
