//
//  BirdObservation.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import Foundation

// ----------------------------------------
// Model for eBird API recent observations response

struct BirdObservation: Codable, Identifiable
{
  let speciesCode : String
  let comName     : String
  let sciName     : String
  let locName     : String
  let obsDt       : String
  let howMany     : Int?
  let lat         : Double
  let lng         : Double

  // Track if this is a new bird
  var isNew       : Bool = false
  
  // ------------------------------
  // Computed property for Identifiable

  var id: String
  {
    speciesCode + obsDt
  } // id
  
  // ------------------------------
  // Create a location-based identifier for tracking seen birds
  // This combines species and location so same bird at different location is "new"

  var locationBasedId: String
  {
    "\(speciesCode)_\(locName)"
  } // locationBasedId
  
  // ------------------------------

  enum CodingKeys: String, CodingKey
  {
    case speciesCode, comName, sciName, locName, obsDt, howMany, lat, lng
  } // CodingKeys
} // struct BirdObservation
