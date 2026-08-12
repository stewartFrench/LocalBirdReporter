//
//  LocalBirdReporterApp.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import SwiftUI

// ----------------------------------------

@main
struct LocalBirdReporterApp: App
{
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  // ------------------------------

  var body: some Scene
  {
    WindowGroup
    {
      ContentView()
    } // WindowGroup
  } // body
} // struct LocalBirdReporterApp

// ----------------------------------------
// Force portrait orientation only

class AppDelegate: NSObject, UIApplicationDelegate
{
  // ------------------------------

  func application(
    _ application                           : UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask
  {
    return .portrait
  } // application
} // class AppDelegate
