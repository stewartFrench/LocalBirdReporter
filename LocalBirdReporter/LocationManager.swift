//
//  LocationManager.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import Foundation
import CoreLocation

// ----------------------------------------

class LocationManager: NSObject, CLLocationManagerDelegate
{
  private let manager             : CLLocationManager = CLLocationManager()

  var location                    : CLLocation?

  var authorizationStatus         : CLAuthorizationStatus = .notDetermined

  // ------------------------------

  override init()
  {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyKilometer
    manager.allowsBackgroundLocationUpdates = true
    manager.pausesLocationUpdatesAutomatically = false
  } // init

  // ------------------------------

  func requestLocation()
  {

            // Request always authorization for background location

    manager.requestAlwaysAuthorization()

            // Start continuous location monitoring

    manager.startUpdatingLocation()
  } // requestLocation

  // ------------------------------

  func stopLocationUpdates()
  {
    manager.stopUpdatingLocation()
  } // stopLocationUpdates

  // MARK: - CLLocationManagerDelegate

  // ------------------------------

  func locationManager(
    _ manager                    : CLLocationManager,
    didUpdateLocations locations : [CLLocation]
  )
  {
    location = locations.first
  } // locationManager didUpdateLocations

  // ------------------------------

  func locationManager(
    _ manager              : CLLocationManager,
    didFailWithError error : Error
  )
  {
    print("Location error: \(error.localizedDescription)")
  } // locationManager didFailWithError

  // ------------------------------

  func locationManagerDidChangeAuthorization(
    _ manager: CLLocationManager
  )
  {
    authorizationStatus = manager.authorizationStatus
  } // locationManagerDidChangeAuthorization
} // class LocationManager
