//
//  BirdReporterViewModel.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import Foundation
import CoreLocation
import AVFoundation
import UIKit

// ----------------------------------------

enum BirdSortMode: String, CaseIterable, Codable
{
  case closest      = "Closest"
  case mostRecent   = "Most Recently Reported"
  case largestCount = "Largest Number"

} // enum BirdSortMode

// ----------------------------------------

enum DistanceUnit: String, CaseIterable, Codable
{
  case kilometers = "Kilometers"
  case miles      = "Miles"

} // enum DistanceUnit

// ----------------------------------------
// A manually-set location the user can quickly reselect from Change Location

struct RecentLocation: Codable, Identifiable
{
  let name      : String
  let latitude  : Double
  let longitude : Double

  // ------------------------------
  // Computed property for Identifiable

  var id: String
  {
    "\(name)_\(latitude)_\(longitude)"

  } // id

  // ------------------------------

  var coordinate: CLLocationCoordinate2D
  {
    CLLocationCoordinate2D(
      latitude  : latitude,
      longitude : longitude
    )

  } // coordinate

} // struct RecentLocation

// ----------------------------------------

@Observable
class BirdReporterViewModel
{
  var locationManager              : LocationManager
  var birds                        : [BirdObservation] = []
  var isLoading                    = false
  var errorMessage                 : String?
  var distanceMessage              : String?
  var isSpeaking                   = false
  var seenBirdIds                  : Set<String> = []
  var lastKnownLocation            : CLLocation?
  var manualLocation               : CLLocation?
  var manualLocationName           : String?
  var isUsingManualLocation        = false
  var shouldScrollToTop            = false

  var maxBirdsToDisplay: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        maxBirdsToDisplay,
        forKey: "maxBirdsToDisplay"
      )

    } // didSet

  } // var maxBirdsToDisplay

  var maxBirdsToSpeak: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        maxBirdsToSpeak,
        forKey: "maxBirdsToSpeak"
      )

    } // didSet

  } // var maxBirdsToSpeak

  var checkIntervalMinutes: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        checkIntervalMinutes,
        forKey: "checkIntervalMinutes"
      )

              // If auto-check is running, restart it with new interval

      if isAutoCheckEnabled
      {
        startAutoCheck()

      } // if

    } // didSet

  } // var checkIntervalMinutes

  var resetDistanceKm: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        resetDistanceKm,
        forKey: "resetDistanceKm"
      )

              // Clear distance message when threshold changes

      distanceMessage = nil

    } // didSet

  } // var resetDistanceKm

  var searchRadiusKm: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        searchRadiusKm,
        forKey: "searchRadiusKm"
      )

    } // didSet

  } // var searchRadiusKm

  var daysBack: Int
  {
    didSet
    {
      UserDefaults.standard.set(
        daysBack,
        forKey: "daysBack"
      )

    } // didSet

  } // var daysBack

  var sortMode: BirdSortMode
  {
    didSet
    {
      if let encoded = try? JSONEncoder().encode(sortMode)
      {
        UserDefaults.standard.set(
          encoded,
          forKey: "birdSortMode"
        )

      } // if

              // Re-sort the existing birds list when sort mode changes
              // Do NOT trigger speaking, only update display

      if let location = locationManager.location
      {
        let allBirds = birds
        let sortedBirds = sortBirds(
          allBirds,
          userLocation: location
        )
        birds = sortedBirds

                // Trigger scroll to top in the view

        shouldScrollToTop = true

      } // if

    } // didSet

  } // var sortMode

  var distanceUnit: DistanceUnit
  {
    didSet
    {
      if let encoded = try? JSONEncoder().encode(distanceUnit)
      {
        UserDefaults.standard.set(
          encoded,
          forKey: "distanceUnit"
        )

      } // if

              // Clear distance message when unit changes so it updates on next fetch

      distanceMessage = nil

    } // didSet

  } // var distanceUnit

  var apiKey: String
  {
    didSet
    {
      UserDefaults.standard.set(
        apiKey,
        forKey: "eBirdAPIKey"
      )

      birdService.apiKey = apiKey

    } // didSet

  } // var apiKey

  var selectedVoiceIdentifier: String?
  {
    didSet
    {
      UserDefaults.standard.set(
        selectedVoiceIdentifier,
        forKey: "selectedVoiceIdentifier"
      )

      speech.selectedVoiceIdentifier = selectedVoiceIdentifier

    } // didSet

  } // var selectedVoiceIdentifier

  var announceNoNewBirds: Bool
  {
    didSet
    {
      UserDefaults.standard.set(
        announceNoNewBirds,
        forKey: "announceNoNewBirds"
      )

    } // didSet

  } // var announceNoNewBirds

  var recentLocations: [RecentLocation] = []
  {
    didSet
    {
      if let encoded = try? JSONEncoder().encode(recentLocations)
      {
        UserDefaults.standard.set(
          encoded,
          forKey: "recentLocations"
        )

      } // if

    } // didSet

  } // var recentLocations

  private var birdService   : eBirdService
  private var speech        : SpeechService
  private var timer         : Timer?
  private var speechEndTask : Task<Void, Never>?
  var isAutoCheckEnabled    : Bool = false
  private var audioPlayer   : AVAudioPlayer?

  // ------------------------------

  init()
  {

            // Initialize required properties first

    locationManager = LocationManager()
    birdService = eBirdService()
    speech = SpeechService()

    maxBirdsToDisplay = UserDefaults.standard.object(
      forKey: "maxBirdsToDisplay"
    ) as? Int ?? 50

    maxBirdsToSpeak = UserDefaults.standard.object(
      forKey: "maxBirdsToSpeak"
    ) as? Int ?? 10

    checkIntervalMinutes = UserDefaults.standard.object(
      forKey: "checkIntervalMinutes"
    ) as? Int ?? 2

    resetDistanceKm = UserDefaults.standard.object(
      forKey: "resetDistanceKm"
    ) as? Int ?? 3

    searchRadiusKm = UserDefaults.standard.object(
      forKey: "searchRadiusKm"
    ) as? Int ?? 3

    daysBack = UserDefaults.standard.object(
      forKey: "daysBack"
    ) as? Int ?? 7

    if let savedSortMode = UserDefaults.standard.data(
      forKey: "birdSortMode"
    ),
       let decoded = try? JSONDecoder().decode(
         BirdSortMode.self,
         from: savedSortMode
       )
    {
      sortMode = decoded

    } // if
    else
    {
      sortMode = .largestCount

    } // else

    if let savedDistanceUnit = UserDefaults.standard.data(
      forKey: "distanceUnit"
    ),
       let decoded = try? JSONDecoder().decode(
         DistanceUnit.self,
         from: savedDistanceUnit
       )
    {
      distanceUnit = decoded

    } // if
    else
    {
      distanceUnit = .kilometers

    } // else

    apiKey = UserDefaults.standard.string(
      forKey: "eBirdAPIKey"
    ) ?? ""

    selectedVoiceIdentifier = UserDefaults.standard.string(
      forKey: "selectedVoiceIdentifier"
    )

    announceNoNewBirds = UserDefaults.standard.object(
      forKey: "announceNoNewBirds"
    ) as? Bool ?? false

    birdService.apiKey = apiKey
    speech.selectedVoiceIdentifier = selectedVoiceIdentifier

    if let savedIds = UserDefaults.standard.array(
      forKey: "seenBirdIds"
    ) as? [String]
    {
      seenBirdIds = Set(savedIds)

    } // if

    if let savedRecentLocations = UserDefaults.standard.data(
      forKey: "recentLocations"
    ),
       let decodedLocations = try? JSONDecoder().decode(
         [RecentLocation].self,
         from: savedRecentLocations
       )
    {
      recentLocations = decodedLocations

    } // if

            // Now setup silent audio and notifications

    setupSilentAudioPlayer()
    setupNotifications()

    if let savedBirdsData = UserDefaults.standard.data(
      forKey: "savedBirds"
    ),
       let savedBirds = try? JSONDecoder().decode(
         [BirdObservation].self,
         from: savedBirdsData
       )
    {
      birds = savedBirds

    } // if

            // Clear last known location on app launch
            // This ensures every app launch starts fresh with "First location check"
            // and prevents GPS drift from showing false movement messages

    lastKnownLocation = nil
    UserDefaults.standard.removeObject(forKey: "lastKnownLatitude")
    UserDefaults.standard.removeObject(forKey: "lastKnownLongitude")

            // Mark first launch (but don't enable auto-check by default)

    if UserDefaults.standard.object(forKey: "hasLaunchedBefore") == nil
    {
      UserDefaults.standard.set(
        true,
        forKey: "hasLaunchedBefore"
      )

    } // if

  } // init

  // ------------------------------

  func requestLocation()
  {
    locationManager.requestLocation()

  } // func requestLocation

  // ------------------------------

  func startAutoCheck()
  {
    stopAutoCheck()
    isAutoCheckEnabled = true

            // Start silent audio to keep app active in background

    startSilentAudio()

    let intervalSeconds = TimeInterval(checkIntervalMinutes * 60)

    timer = Timer.scheduledTimer(
      withTimeInterval: intervalSeconds,
      repeats         : true
    )
    {
      [weak self] _ in

      print("Auto-check timer fired at \(Date())")
      self?.fetchBirds(isAutoCheck: true)

    } // timer

            // Add timer to run loop for background execution

    if let timer = timer
    {
      RunLoop.main.add(
        timer,
        forMode: .common
      )

    } // if

    print("Auto-check started, interval: \(checkIntervalMinutes) minutes")
    print("Silent audio playing: \(audioPlayer?.isPlaying ?? false)")

  } // func startAutoCheck

  // ------------------------------

  func stopAutoCheck()
  {
    timer?.invalidate()
    timer = nil
    isAutoCheckEnabled = false

            // Stop silent audio when auto-check is stopped

    stopSilentAudio()

  } // func stopAutoCheck

  // ------------------------------

  func stopSpeaking()
  {
    speechEndTask?.cancel()
    speech.stopSpeaking()
    isSpeaking = false

  } // func stopSpeaking

  // ------------------------------

  func fetchBirds(
    isAutoCheck: Bool = false
  )
  {
    if apiKey.isEmpty
    {
      errorMessage = "Please add your eBird API key in Settings."
      return

    } // if

    isLoading = true
    errorMessage = nil

    Task
    {

              // Use manual location if set, otherwise request fresh GPS location

      let location: CLLocation

      if let manual = manualLocation, isUsingManualLocation
      {
        location = manual

      } // if
      else
      {
        await MainActor.run
        {
          locationManager.requestLocation()

        } // await MainActor.run

                // Wait for location update (up to 5 seconds)

        for _ in 0..<10
        {
          try? await Task.sleep(nanoseconds: 500_000_000)

          if locationManager.location != nil
          {
            break

          } // if

        } // for

        guard let gpsLocation = locationManager.location
        else
        {
          await MainActor.run
          {
            errorMessage = "Location not available. Please check " +
                           "Settings > Privacy > Location Services " +
                           "and ensure it's enabled for this app."
            isLoading = false

          } // await MainActor.run

          return

        } // guard

        location = gpsLocation

      } // else

              // Check if location has changed significantly (only when NOT using manual location)

      await MainActor.run
      {
        print(
          "Current location: " +
          "\(location.coordinate.latitude), " +
          "\(location.coordinate.longitude)"
        )

                // Skip distance-based reset when using manual location

        if !isUsingManualLocation
        {
          print("Reset distance threshold: \(resetDistanceKm) km")

          if let lastLocation = lastKnownLocation
          {
            let distanceInMeters = location.distance(from: lastLocation)
            let distanceInKm     = distanceInMeters / 1000.0
            let distanceInMiles  = distanceInMeters / 1609.34

            print(
              "Last location: " +
              "\(lastLocation.coordinate.latitude), " +
              "\(lastLocation.coordinate.longitude)"
            )
            print(
              "Distance from last location: " +
              "\(String(format: "%.1f", distanceInKm)) km"
            )

                    // Format distance based on user preference

            let distanceValue  = distanceUnit == .miles ? distanceInMiles : distanceInKm
            let distanceString = String(format: "%.1f", distanceValue)
            let unitString     = distanceUnit == .miles ? "mi" : "km"
            let thresholdValue = distanceUnit == .miles
              ? Int(Double(resetDistanceKm) / 1.60934)
              : resetDistanceKm

            if distanceInKm > Double(resetDistanceKm)
            {

                      // Significant location change - clear everything and start fresh

              print(
                "Location changed by " +
                "\(String(format: "%.1f", distanceInKm)) km - resetting seen birds"
              )
              distanceMessage = "Moved \(distanceString) \(unitString) - Reset birds"

                      // Clear seen bird IDs

              seenBirdIds.removeAll()
              saveSeenBirdIds()

                      // Clear birds list for fresh start

              birds.removeAll()
              saveBirds()

                      // Update last known location ONLY when we reset

              lastKnownLocation = location
              UserDefaults.standard.set(
                location.coordinate.latitude,
                forKey: "lastKnownLatitude"
              )
              UserDefaults.standard.set(
                location.coordinate.longitude,
                forKey: "lastKnownLongitude"
              )

            } // if
            else
            {
              print(
                "Distance \(String(format: "%.1f", distanceInKm)) km is less than " +
                "threshold \(resetDistanceKm) km - NOT resetting"
              )
              distanceMessage = "Moved \(distanceString) \(unitString) " +
                                "(< \(thresholdValue) \(unitString) threshold)"

            } // else

          } // if
          else
          {
            print("No last known location - this is first fetch")
            distanceMessage = "First location check"

                    // Set initial last known location on first fetch

            lastKnownLocation = location
            UserDefaults.standard.set(
              location.coordinate.latitude,
              forKey: "lastKnownLatitude"
            )
            UserDefaults.standard.set(
              location.coordinate.longitude,
              forKey: "lastKnownLongitude"
            )

          } // else

        } // if
        else
        {

                  // Using manual location - no distance-based updates

          print("Using manual location - no distance tracking")

        } // else

      } // await MainActor.run

      do
      {
        let observations = try await birdService.fetchRecentObservations(
          latitude   : location.coordinate.latitude,
          longitude  : location.coordinate.longitude,
          daysBack   : daysBack,
          maxResults : maxBirdsToDisplay,
          distanceKm : searchRadiusKm
        )

        print("Fetched \(observations.count) observations from eBird")
        for obs in observations.prefix(5)
        {
          print("  - \(obs.comName) at \(obs.locName), \(obs.obsDt)")

        } // for

        await MainActor.run
        {
          var newOrChangedBirds : [BirdObservation] = []
          var unchangedBirds    : [BirdObservation] = []

          for var observation in observations
          {

                    // Use location-based ID so same species at different location is "new"

            let locationId = observation.locationBasedId

            if seenBirdIds.contains(locationId)
            {
              unchangedBirds.append(observation)

            } // if
            else
            {
              observation.isNew = true
              newOrChangedBirds.append(observation)
              seenBirdIds.insert(locationId)

            } // else

          } // for

                  // Sort new birds by user's preference

          let sortedNewBirds = sortBirds(
            newOrChangedBirds,
            userLocation: location
          )

                  // Sort unchanged birds by user's preference

          let sortedExistingBirds = sortBirds(
            unchangedBirds,
            userLocation: location
          )

                  // Display: new birds first, then unchanged birds

          let combinedBirds = sortedNewBirds + sortedExistingBirds

          birds = Array(combinedBirds.prefix(maxBirdsToDisplay))

          saveBirds()
          saveSeenBirdIds()

                  // Speech behavior depends on whether this is an auto-check

          if isAutoCheck
          {

                    // Auto-check: only speak new birds

            speakNewBirdsOnly(
              newOrChangedBirds,
              userLocation: location
            )

          } // if
          else
          {

                    // Manual fetch: speak new birds first, then unchanged birds
                    // Use the same sort order as display (user's selected sort mode)

            let newBirdsSorted = sortBirds(
              newOrChangedBirds,
              userLocation: location
            )

            let unchangedBirdsSorted = sortBirds(
              unchangedBirds,
              userLocation: location
            )

                    // Prioritize new birds, then add unchanged birds to fill up to maxBirdsToSpeak

            let birdsToSpeak = newBirdsSorted + unchangedBirdsSorted

            speakBirdsInOrder(Array(birdsToSpeak.prefix(maxBirdsToSpeak)))

          } // else

          isLoading = false

                  // Scroll to top after fetch completes
                  // Reset to false first to ensure onChange triggers

          shouldScrollToTop = false
          Task
          {
            @MainActor in

            shouldScrollToTop = true

          } // Task

        } // await MainActor.run

      } // do
      catch
      {
        await MainActor.run
        {
          if let urlError = error as? URLError,
             urlError.code == .badServerResponse
          {
            errorMessage = "Invalid API key. Please check your " +
                           "eBird API key in Settings."

          } // if
          else
          {
            errorMessage = "Failed to fetch birds: " +
                           "\(error.localizedDescription)"

          } // else

          isLoading = false

        } // await MainActor.run

      } // catch

    } // Task

  } // func fetchBirds

  // ------------------------------

  func setManualLocation(
    _ location : CLLocation,
    name       : String
  )
  {
    manualLocation = location
    manualLocationName = name
    isUsingManualLocation = true

    addRecentLocation(
      name     : name,
      location : location
    )

            // Clear everything for fresh start at new location

    seenBirdIds.removeAll()
    saveSeenBirdIds()

    birds.removeAll()
    saveBirds()

    lastKnownLocation = nil
    UserDefaults.standard.removeObject(forKey: "lastKnownLatitude")
    UserDefaults.standard.removeObject(forKey: "lastKnownLongitude")

    distanceMessage = "Manual location set"

  } // func setManualLocation

  // ------------------------------

  func clearManualLocation()
  {
    manualLocation = nil
    manualLocationName = nil
    isUsingManualLocation = false

            // Clear everything for fresh start with real GPS

    seenBirdIds.removeAll()
    saveSeenBirdIds()

    birds.removeAll()
    saveBirds()

    lastKnownLocation = nil
    UserDefaults.standard.removeObject(forKey: "lastKnownLatitude")
    UserDefaults.standard.removeObject(forKey: "lastKnownLongitude")

    distanceMessage = "Using current location"

  } // func clearManualLocation

  // ------------------------------

  func addRecentLocation(
    name     : String,
    location : CLLocation
  )
  {
    let newLocation = RecentLocation(
      name      : name,
      latitude  : location.coordinate.latitude,
      longitude : location.coordinate.longitude
    )

            // Remove any existing entry for this name so it moves to the front

    recentLocations.removeAll
    {
      $0.name == name

    } // removeAll

    recentLocations.insert(
      newLocation,
      at: 0
    )

    if recentLocations.count > 5
    {
      recentLocations = Array(recentLocations.prefix(5))

    } // if

  } // func addRecentLocation

  // ------------------------------

  func resetToDefaults()
  {
    sortMode                = .largestCount
    searchRadiusKm          = 3
    daysBack                = 7
    maxBirdsToDisplay       = 50
    resetDistanceKm         = 3
    checkIntervalMinutes    = 2
    announceNoNewBirds      = false
    maxBirdsToSpeak         = 10
    selectedVoiceIdentifier = nil
    distanceUnit            = .kilometers

    if isAutoCheckEnabled
    {
      stopAutoCheck()

    } // if

    if isUsingManualLocation
    {
      clearManualLocation()

    } // if

  } // func resetToDefaults

  // ------------------------------

  private func speakBirdsInOrder(
    _ birds: [BirdObservation]
  )
  {
    guard !birds.isEmpty
    else
    {
      return

    } // guard

            // Check if all birds are new

    let allBirdsAreNew = birds.allSatisfy
    {
      $0.isNew

    } // allSatisfy

    var speechParts: [String] = []

            // Add "New Birds" prefix if all birds are new

    if allBirdsAreNew
    {
      speechParts.append("New Birds")

    } // if

    for bird in birds
    {
      var birdText = ""

              // Only say "New" if not all birds are new (mixed scenario)

      if bird.isNew && !allBirdsAreNew
      {
        birdText = "New, "

      } // if

              // Add count before bird name if available

      if let count = bird.howMany
      {
        birdText += "\(count) "

      } // if

      birdText += bird.comName

      speechParts.append(birdText)

    } // for

    if !speechParts.isEmpty
    {
      speechEndTask?.cancel()

      isSpeaking = true
      let combinedText = speechParts.joined(separator: ",, ")
      speech.speak(combinedText)

      let estimatedDuration = Double(speechParts.count) * 2.0

      speechEndTask = Task
      {
        try? await Task.sleep(
          nanoseconds: UInt64(estimatedDuration * 1_000_000_000)
        )

        await MainActor.run
        {
          isSpeaking = false

        } // await MainActor.run

      } // speechEndTask

    } // if

  } // func speakBirdsInOrder

  // ------------------------------

  private func speakNewBirdsOnly(
    _ newBirds   : [BirdObservation],
    userLocation : CLLocation
  )
  {

            // Sort new birds using user's selected sort mode

    let sortedNewBirds = sortBirds(
      newBirds,
      userLocation: userLocation
    )

    let birdsToSpeak = Array(sortedNewBirds.prefix(maxBirdsToSpeak))

    if birdsToSpeak.isEmpty
    {

              // No new birds - announce this only if enabled

      if announceNoNewBirds
      {
        speechEndTask?.cancel()

        isSpeaking = true
        speech.speak("No new birds")

        speechEndTask = Task
        {
          try? await Task.sleep(nanoseconds: 2_000_000_000)

          await MainActor.run
          {
            isSpeaking = false

          } // await MainActor.run

        } // speechEndTask

      } // if announceNoNewBirds

      return

    } // if

            // We have new birds - speak them

    var speechParts: [String] = ["New Birds"]

    for bird in birdsToSpeak
    {
      var birdText = ""

              // Add count before bird name if available

      if let count = bird.howMany
      {
        birdText = "\(count) "

      } // if

      birdText += bird.comName

      speechParts.append(birdText)

    } // for

    speechEndTask?.cancel()

    isSpeaking = true
    let combinedText = speechParts.joined(separator: ",, ")
    speech.speak(combinedText)

    let estimatedDuration = Double(speechParts.count) * 2.0

    speechEndTask = Task
    {
      try? await Task.sleep(
        nanoseconds: UInt64(estimatedDuration * 1_000_000_000)
      )

      await MainActor.run
      {
        isSpeaking = false

      } // await MainActor.run

    } // speechEndTask

  } // func speakNewBirdsOnly

  // ------------------------------

  private func saveBirds()
  {
    if let encoded = try? JSONEncoder().encode(birds)
    {
      UserDefaults.standard.set(
        encoded,
        forKey: "savedBirds"
      )

    } // if

  } // func saveBirds

  // ------------------------------

  private func saveSeenBirdIds()
  {
    let idsArray = Array(seenBirdIds)

    UserDefaults.standard.set(
      idsArray,
      forKey: "seenBirdIds"
    )

  } // func saveSeenBirdIds

  // ------------------------------

  private func setupSilentAudioPlayer()
  {

            // Create a 1 second silent audio buffer

    let sampleRate = 44100.0
    let duration   = 1.0
    let frameCount = UInt32(sampleRate * duration)

    guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels                    : 1
          ),
          let buffer = AVAudioPCMBuffer(
            pcmFormat     : format,
            frameCapacity : frameCount
          )
    else
    {
      return

    } // guard

    buffer.frameLength = frameCount

            // Fill with silence (zeros)

    if let channelData = buffer.floatChannelData
    {
      let data = channelData[0]
      for i in 0..<Int(frameCount)
      {
        data[i] = 0.0

      } // for

    } // if

            // Create temporary file for silent audio

    let tempDir    = FileManager.default.temporaryDirectory
    let silenceURL = tempDir.appendingPathComponent("silence.caf")

    do
    {

              // Write silent audio to file

      let audioFile = try AVAudioFile(
        forWriting : silenceURL,
        settings   : format.settings
      )
      try audioFile.write(from: buffer)

              // Setup audio player with the silent file

      audioPlayer = try AVAudioPlayer(contentsOf: silenceURL)
      audioPlayer?.numberOfLoops = -1
      audioPlayer?.volume        = 0.0
      audioPlayer?.prepareToPlay()

    } // do
    catch
    {
      print("Failed to setup silent audio player: \(error)")

    } // catch

  } // setupSilentAudioPlayer

  // ------------------------------

  private func startSilentAudio()
  {
    guard let player = audioPlayer
    else
    {
      return

    } // guard

            // Configure audio session for background playback

    do
    {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(
        .playback,
        mode    : .voicePrompt,
        options : [.mixWithOthers]
      )
      try audioSession.setActive(true)

    } // do
    catch
    {
      print("Failed to configure audio session: \(error)")

    } // catch

    if !player.isPlaying
    {
      player.play()

              // Verify playback started after a brief delay

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
      {
        [weak self] in

        if self?.audioPlayer?.isPlaying == false
        {

                  // Retry if failed

          self?.audioPlayer?.play()

        } // if

      } // asyncAfter

    } // if

  } // startSilentAudio

  // ------------------------------

  private func stopSilentAudio()
  {
    audioPlayer?.stop()

  } // stopSilentAudio

  // ------------------------------

  private func setupNotifications()
  {

            // Observe audio session interruptions

    NotificationCenter.default.addObserver(
      self,
      selector : #selector(handleAudioSessionInterruption),
      name     : AVAudioSession.interruptionNotification,
      object   : AVAudioSession.sharedInstance()
    )

            // Monitor app lifecycle

    NotificationCenter.default.addObserver(
      self,
      selector : #selector(appDidEnterBackground),
      name     : UIApplication.didEnterBackgroundNotification,
      object   : nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector : #selector(appWillEnterForeground),
      name     : UIApplication.willEnterForegroundNotification,
      object   : nil
    )

  } // setupNotifications

  // ------------------------------

  @objc private func handleAudioSessionInterruption(
    notification: Notification
  )
  {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else
    {
      return

    } // guard

    if type == .ended
    {

              // Interruption ended - restart silent audio if auto-check is enabled

      if isAutoCheckEnabled
      {
        do
        {
          try AVAudioSession.sharedInstance().setActive(true)
          startSilentAudio()

        } // do
        catch
        {
          print("Failed to reactivate audio session: \(error)")

        } // catch

      } // if

    } // if

  } // handleAudioSessionInterruption

  // ------------------------------

  @objc private func appDidEnterBackground()
  {

            // Ensure silent audio is playing when entering background

    if isAutoCheckEnabled
    {
      startSilentAudio()

    } // if

  } // appDidEnterBackground

  // ------------------------------

  @objc private func appWillEnterForeground()
  {

            // Verify silent audio is still running

    if isAutoCheckEnabled
    {
      if audioPlayer?.isPlaying == false
      {
        startSilentAudio()

      } // if

    } // if

  } // appWillEnterForeground

  // ------------------------------

  private func sortBirds(
    _ birds       : [BirdObservation],
    userLocation  : CLLocation,
    forceSortMode : BirdSortMode? = nil
  ) -> [BirdObservation]
  {
    let modeToUse = forceSortMode ?? sortMode

    switch modeToUse
    {
    case .largestCount:
      return birds.sorted
      {
        first, second in

        let firstCount  = first.howMany ?? 0
        let secondCount = second.howMany ?? 0

        return firstCount > secondCount

      } // sorted

    case .mostRecent:
      return birds.sorted
      {
        first, second in

        return first.obsDt > second.obsDt

      } // sorted

    case .closest:
      return birds.sorted
      {
        first, second in

        let firstLocation = CLLocation(
          latitude  : first.lat,
          longitude : first.lng
        )

        let secondLocation = CLLocation(
          latitude  : second.lat,
          longitude : second.lng
        )

        let firstDistance  = userLocation.distance(from: firstLocation)
        let secondDistance = userLocation.distance(from: secondLocation)

                // If distances are essentially the same (within 1 meter), sort by count

        if abs(firstDistance - secondDistance) < 1.0
        {
          let firstCount  = first.howMany ?? 0
          let secondCount = second.howMany ?? 0
          return firstCount > secondCount

        } // if

        return firstDistance < secondDistance

      } // sorted

    } // switch

  } // func sortBirds

} // class BirdReporterViewModel
