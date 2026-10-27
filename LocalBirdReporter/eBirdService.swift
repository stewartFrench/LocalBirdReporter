//
//  eBirdService.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import Foundation
import CoreLocation

// ----------------------------------------

class eBirdService
{

          // eBird API key - users will enter their own from https://ebird.org/api/keygen

  var apiKey          : String = ""

  private let baseURL : String = "https://api.ebird.org/v2/data/obs/geo/recent"

  // ------------------------------

          // Fetch recent bird observations within radius of location

  func fetchRecentObservations(
    latitude   : Double,
    longitude  : Double,
    daysBack   : Int = 7,
    maxResults : Int = 10,
    distanceKm : Int = 5
  ) async throws -> [BirdObservation]
  {

            // Build URL with query parameters

    var components = URLComponents(string: baseURL)
    components?.queryItems = [
      URLQueryItem(
        name  : "lat",
        value : String(latitude)
      ),
      URLQueryItem(
        name  : "lng",
        value : String(longitude)
      ),
      URLQueryItem(
        name  : "back",
        value : String(daysBack)
      ),
      URLQueryItem(
        name  : "maxResults",
        value : String(maxResults)
      ),
      URLQueryItem(
        name  : "dist",
        value : String(distanceKm)
      )
    ]

    guard let url = components?.url
    else
    {
      throw URLError(.badURL)
    } // else

    var request = URLRequest(url: url)
    request.addValue(
      apiKey,
      forHTTPHeaderField: "X-eBirdApiToken"
    )

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200
    else
    {
      throw URLError(.badServerResponse)
    } // else

    let decoder = JSONDecoder()
    let observations = try decoder.decode(
      [BirdObservation].self,
      from: data
    )

    return observations
  } // fetchRecentObservations
} // class eBirdService
