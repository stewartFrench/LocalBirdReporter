# Software Design Document
## Local Bird Reporter iOS Application
## Built in Xcode as "LocalBirdReporter"

**Version:** 1.0

**Date:** August 12, 2026

**Author:** Stewart French, Claude Sonnet 4.5 by Anthropic

## Table of Contents

  1. [Overview](#overview)
  2. [Architecture](#architecture)
  3. [Core Features](#core-features)
  4. [Data Models](#data-models)
  5. [Services](#services)
  6. [User Interface](#user-interface)
  7. [Settings & Configuration](#settings--configuration)
  8. [Background Operation](#background-operation)
  9. [Location Services](#location-services)
  10. [Speech & Audio](#speech--audio)
  11. [Data Persistence](#data-persistence)
  12. [API Integration](#api-integration)

---

## Overview

### Purpose

Local Bird Reporter is an iOS application that helps birders discover
nearby bird observations while driving or moving through different
areas. The app automatically announces new birds via speech synthesis
and maintains awareness of location changes.

### Key Capabilities

  - Fetch recent bird observations from eBird API based on current GPS
    location
    
  - Automatically check for new birds at configurable intervals

  - Speak bird names and counts using text-to-speech

  - Track which birds have been "seen" and identify new observations

  - Reset bird list when moving beyond a configurable distance
    threshold

  - Operate in background with location updates and speech
    announcements


### Target Platform

- iOS 17.0+
- iPhone (primary), iPad (supported)
- SwiftUI-based interface

---

## Architecture

### Design Pattern
The app follows the MVVM (Model-View-ViewModel) architecture pattern:

```
┌─────────────────┐
│     Views       │  SwiftUI Views
│  ContentView    │  - Main bird list
│  SettingsView   │  - Configuration UI
│  AbouteBirdView │  - Information screen
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│       ViewModel             │  @Observable
│  BirdReporterViewModel      │  - Business logic
│                             │  - State management
│                             │  - Coordinates services
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│        Services             │
│  - eBirdService             │  API integration
│  - LocationManager          │  GPS tracking
│  - SpeechService            │  Text-to-speech
└─────────────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│         Models              │
│  - BirdObservation          │  Data structures
│  - BirdSortMode             │  Enums
│  - DistanceUnit             │
└─────────────────────────────┘
```

### Key Architectural Decisions

  1. **Observable Pattern**: Uses Swift's `@Observable` macro for
     reactive state management
     
  2. **Single ViewModel**: BirdReporterViewModel manages all app state
     and coordinates services
     
  3. **Service Separation**: Clear separation between API, location,
     and speech services
     
  4. **UserDefaults Persistence**: Simple key-value storage for
     settings and state
     
  5. **Background Audio**: Uses silent audio playback to maintain
     background operation

---

## Core Features

### 1. Bird Discovery
     
**Purpose**: Fetch and display nearby bird observations

**Flow**:
     
  1. User taps "Fetch Local Birds" or auto-check timer fires
  2. App requests current GPS location
  3. Calls eBird API with location, radius, and days back parameters
  4. Receives array of bird observations
  5. Categorizes birds as "new" or "previously seen"
  6. Displays sorted list (new birds first)
  7. Speaks bird names using text-to-speech

**Key Components**:
     
- `fetchBirds(isAutoCheck: Bool)` in BirdReporterViewModel
- `fetchRecentObservations()` in eBirdService
- Location tracking via LocationManager

### 2. New Bird Detection
     
**Purpose**: Track which birds have been seen and identify new
             observations

**Logic**:
     
```swift
  // Bird uniqueness is determined by species + location
     
  let locationBasedId = "\(speciesCode)_\(locName)"

  if seenBirdIds.contains(locationBasedId) 
  {
      // Previously seen bird
      unchangedBirds.append(observation)
  } else {
      // New bird
      observation.isNew = true
      newOrChangedBirds.append(observation)
      seenBirdIds.insert(locationBasedId)
  }
```

**Key Points**:

  - Same species at different locations counts as "new"
  - Seen bird IDs persist across app launches
  - New birds displayed with animated 🆕 emoji badge

### 3. Location-Based Reset

**Purpose**: Clear seen birds when user moves to a new area

**Logic**:

  1. On each fetch, calculate distance from last known location
  2. If distance > threshold (e.g., 8 km), reset:
     - Clear `seenBirdIds` set
     - Clear `birds` array
     - Update last known location to current position
  3. If distance < threshold, keep existing state

**Key Variables**:

  - `lastKnownLocation: CLLocation?` - Reference point for distance
     calculation
  - `resetDistanceKm: Int` - Configurable threshold (default 8 km)
  - Only updates last known location when reset occurs (not on every
    fetch)

### 4. Auto-Check

**Purpose**: Automatically check for new birds at regular intervals

**Implementation**:

```swift
  timer = Timer.scheduledTimer(
      withTimeInterval: TimeInterval(checkIntervalMinutes * 60),
               repeats: true
  ) 
  { [weak self] _ in
      self?.fetchBirds(isAutoCheck: true)
  }
  RunLoop.main.add(timer, forMode: .common)
```

**Key Points**:

- Timer added to `.common` run loop mode for background execution
- Silent audio keeps app active in background
- Auto-check speaks only new birds (not all birds)
- Configurable interval (default 5 minutes)

---

## Data Models

### BirdObservation
```swift
  struct BirdObservation: Codable, Identifiable 
  {
      let speciesCode: String      // e.g., "norcad"
      let comName: String          // e.g., "Northern Cardinal"
      let sciName: String          // e.g., "Cardinalis cardinalis"
      let locName: String          // e.g., "Oak Point Park"
      let obsDt: String            // e.g., "2026-08-10 14:30"
      let howMany: Int?            // Count of individuals
      let lat: Double              // Latitude
      let lng: Double              // Longitude
      var isNew: Bool = false      // Marked as new by app
  
      var id: String 
      {
          "\(speciesCode)_\(obsDt)"  // Unique ID for SwiftUI
      }
  
      var locationBasedId: String 
      {
          "\(speciesCode)_\(locName)" // For tracking "seen" birds
      }
  } // struct
```

### BirdSortMode
```swift
  enum BirdSortMode: String, CaseIterable, Codable 
  {
    case closest      = "Closest to Me"
    case mostRecent   = "Most Recently Reported"
    case largestCount = "Largest Number"
  }
```

### DistanceUnit
```swift
  enum DistanceUnit: String, CaseIterable, Codable 
  {
      case kilometers = "Kilometers"
      case miles      = "Miles"
  }
```

---

## Services

### eBirdService

**Purpose**: Interface with eBird API v2

**Configuration**:

  - Base URL: `https://api.ebird.org/v2/data/obs/geo/recent`
  - Authentication: API key in `X-eBirdApiToken` header
  - Users must obtain free API key from https://ebird.org/api/keygen

**Key Method**:

```swift
  func fetchRecentObservations(
        latitude: Double,
       longitude: Double,
        daysBack: Int = 7,
      maxResults: Int = 100,
      distanceKm: Int = 5
  ) async throws -> [BirdObservation]
```

**Parameters**:

  - `lat/lng`: GPS coordinates
  - `back`: Days back to search (default 7)
  - `maxResults`: Maximum observations to return (100)
  - `dist`: Search radius in kilometers (default 5)

**Error Handling**:

  - Invalid API key: Shows user-friendly error message
  - Network errors: Displays error text
  - Bad responses: URLError.badServerResponse

### LocationManager

**Purpose**: Manage GPS location services

**Capabilities**:

  - Request location permissions (Always authorization)
  - Continuous location updates via `startUpdatingLocation()`
  - Background location updates enabled
  - Desired accuracy: kCLLocationAccuracyKilometer

**Key Properties**:

```swift
  var location: CLLocation?       // Current location
  var authorizationStatus: CLAuthorizationStatus
  allowsBackgroundLocationUpdates = true
  pausesLocationUpdatesAutomatically = false
```

**Permission Flow**:

  1. Initial: Request "When In Use" permission
  2. After background use detected: iOS prompts for "Always Allow"
  3. Required for reliable background operation

### SpeechService

**Purpose**: Text-to-speech synthesis

**Features**:

  - Configurable voice selection (English voices)
  - Mixing with background audio (silent audio)
  - AVSpeechSynthesizer for speech synthesis

**Configuration**:

```swift
  AVAudioSession.sharedInstance().setCategory(
      .playback,
         mode: .voicePrompt,
      options: [.mixWithOthers]
  )
```

**Key Methods**:

```swift
  func speak(_ text: String)
  func stopSpeaking()
  static func getAvailableVoices() -> [AVSpeechSynthesisVoice]
```

**Speech Patterns**:

  - **All birds new**: "New Birds,, Bird Name, Count,, ..."
  - **Mixed new/old**: "Bird Name, Count, New,, Bird Name, Count,, ..."
  - **No new birds**: "No new birds"

---

## User Interface

### ContentView

**Main Screen Components**:

  1. **Header**

     - App title: "Local Bird Reporter"
     - "Supported by eBird" link (opens AbouteBirdView)
     - Settings gear icon (top-right)
     - Sort mode display: "Sorted by: [mode]"
  
  2. **Status Area**

     - Loading indicator when fetching
     - Distance message: "Moved X.X km (< Y km threshold)"
     - Error messages in red
     - Fixed height: 44pt
  
  3. **Bird List**

     - Scrollable list of observations
     - New birds shown first with 🆕 badge
     - Tappable bird name → opens eBird species page
     - Tappable location → opens Apple Maps
     - Yellow highlight for new birds
     - Displays: name, count, location, date/time
  
  4. **Action Buttons**

     - "Stop Speaking" (red when active, gray when disabled)
     - "Fetch Local Birds" (blue, disabled when loading or speaking)

### SettingsView

**Organized into sections**:

  1. **eBird API**

     - Secure field for API key
     - Link to obtain API key

  2. **Display Settings**
  
     - Display: X birds (stepper, 1-50)
     - Sort by (picker: Closest/Most Recent/Largest Count)
     - Distance units (picker: Kilometers/Miles)
     - Mark all birds New after moving: X km/mi
     - Search radius: X km/mi
     - Show birds from last: X days
  
  3. **Speech Settings**
  
     - Voice (picker of available English voices)
     - Speak: X birds (stepper, 1-30)
  
  4. **Auto Check**
  
     - Check every X minutes (stepper, 1-120)
     - Enable Auto Check (toggle)

### AbouteBirdView

**Information Screen**:

  - Explains eBird partnership
  - Links to eBird website
  - Credits and attribution

---

## Settings & Configuration

### Persisted Settings (UserDefaults)

| Key |   Type   |Default |     Description        |
|-----|----------|--------|------------------------|
| `eBirdAPIKey` 
|     | String   |   ""   | User's eBird API token |
| `maxBirdsToDisplay`
|     | Int      |   50   | Birds shown in list    |
| `maxBirdsToSpeak`
|     | Int      |    7   | Birds announced        |
| `checkIntervalMinutes`
|     | Int      |    5   | Auto-check frequency   |
| `resetDistanceKm`
|     | Int      |    8   | Distance threshold     |
| `searchRadiusKm`
|     | Int      |    2   | eBird search radius    |
| `daysBack`
|     | Int      |    7   | How far back to search |
| `birdSortMode`
|     | Codable  | .closest | Sorting preference   |
| `distanceUnit`
|     | Codable  | .kilometers | Display units     |
| `selectedVoiceIdentifier`
|     | String?  |   nil  | TTS voice              |
| `seenBirdIds`
|     | [String] |    []  | Tracked bird IDs       |
| `savedBirds`
|     | Codable  |    []  | Last bird list         |
| `lastKnownLatitude`
|     | Double?  |   nil  | Last reset location    |
| `lastKnownLongitude`
|     | Double?  |   nil  | Last reset location    |
| `hasLaunchedBefore`
|     | Bool     |  false | First launch flag      |

### Computed Conversions

  - Internal storage: kilometers
  - Display: converted based on `distanceUnit` setting
  - Distance conversion: 1 mile = 1.60934 km

---

## Background Operation

### Strategy

Uses audio background mode with silent audio to maintain execution:

1. **Info.plist Configuration**:

  ```xml
  <key>UIBackgroundModes</key>
  <array>
      <string>audio</string>
      <string>location</string>
  </array>
```

2. **Silent Audio Player**:

   - Creates 1-second silent audio buffer
   - Loops continuously when auto-check enabled
   - AVAudioPlayer with `numberOfLoops = -1`

3. **Timer Execution**:

   - Timer added to `.common` RunLoop mode
   - Continues firing while audio plays
   - Calls `fetchBirds(isAutoCheck: true)` at intervals

4. **App Lifecycle Management**:

   - `appDidEnterBackground`: Ensure silent audio playing
   - `appWillEnterForeground`: Verify audio still active
   - Audio session interruption handling

### Lifecycle Events

```swift
  NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
  )
```

---

## Location Services

### Permission Requirements

  - **When In Use**: Initial permission for foreground use
  - **Always Allow**: Required for background location updates
  - Prompts shown automatically by iOS when background use detected

### Privacy Strings (Info.plist)

```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Local Bird Reporter needs your location to find nearby bird
          observations from eBird.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>

<string>Local Bird Reporter needs continuous access to your location
        to automatically check for new birds as you move to different
        areas, even when the app is in the background.</string>
```

### Location Update Strategy

1. **On Fetch**:

   - Always request fresh location: `requestLocation()`
   - Wait up to 5 seconds for GPS fix
   - Use `startUpdatingLocation()` for continuous updates

2. **Distance Calculation**:

```swift
  let distanceInMeters = location.distance(from: lastLocation)
  let distanceInKm = distanceInMeters / 1000.0
```

3. **Reset Logic**:

   - Only update `lastKnownLocation` when threshold exceeded
   - Prevents incremental drift (small movements don't update reference)

---

## Speech & Audio

### Text-to-Speech Engine

Uses AVFoundation's AVSpeechSynthesizer

**Speech Formatting**:

  - Bird names: As provided by eBird
  - Counts: Numeric value after name
  - Separators: ",, " (double comma for natural pause)
  - Prefix: "New Birds" when all are new
  - Suffix: ", New" for individual new birds in mixed list

**Example Speech Strings**:

```
  "New Birds,, Wood Duck, 2,, Barn Swallow, 8,, Scissor-tailed Flycatcher, 1"

  "Wood Duck, 2,, Barn Swallow, 8, New,, Northern Cardinal, 4"

  "No new birds"
```

### Audio Session Configuration

```swift
  try AVAudioSession.sharedInstance().setCategory(
      .playback,                // Background playback
         mode: .voicePrompt,    // Optimized for speech
      options: [.mixWithOthers] // Mix with other audio
)
```

### Speech Timing

  - Estimated duration: `speechParts.count * 2.0` seconds
  - Used to set `isSpeaking` state
  - Prevents overlapping speech
  - Disables fetch button during speech

---

## Data Persistence

### State Storage Locations

**UserDefaults**:

  - Settings and preferences
  - Seen bird IDs (as array)
  - Last known location coordinates
  - Saved birds (JSON encoded)

**In-Memory Only**:

  - Current bird observations array
  - Location manager state
  - Speech synthesizer state
  - Timer reference

### Save Points

  1. **After Each Fetch**:
  
     - `saveBirds()` - Encode and store bird array
     - `saveSeenBirdIds()` - Convert set to array and store
  
  2. **On Setting Changes**:

     - Immediate save via `didSet` property observers
     - No explicit save call needed
  
  3. **On Location Reset**:

     - Save new last known location coordinates
     - Save cleared seen bird IDs

### Restoration on Launch

```swift

  init() 
  {
      // Restore settings from UserDefaults

      maxBirdsToDisplay = UserDefaults.standard.object(...) ?? 50
  
      // Restore seen bird IDs
      if let savedIds = UserDefaults.standard.array(...) as? [String] 
      {
          seenBirdIds = Set(savedIds)
      }
  
      // Restore last bird list
      if let savedBirdsData = UserDefaults.standard.data(...),
         let savedBirds = try? JSONDecoder().decode(...) 
      {
          birds = savedBirds
      }
  }
```

---

## API Integration

### eBird API v2

**Documentation**: https://documenter.getpostman.com/view/664302/S1ENwy59

**Endpoint Used**:

```
  GET https://api.ebird.org/v2/data/obs/geo/recent
```

**Query Parameters**:

  - `lat`       : Latitude (required)
  - `lng`       : Longitude (required)
  - `back`      : Days back (1-30, default 7)
  - `dist`      : Distance in km (default 5)
  - `maxResults`: Maximum results (default 100)

**Headers**:

  - `X-eBirdApiToken`: User's API key (required)

**Response Format**:

```json
  [
    {
      "speciesCode" : "norcad",
      "comName"     : "Northern Cardinal",
      "sciName"     : "Cardinalis cardinalis",
      "locName"     : "Oak Point Park",
      "obsDt"       : "2026-08-10 14:30",
      "howMany"     : 2,
      "lat"         : 33.094,
      "lng"         : -96.691
    }
]
```

**Rate Limits**: Not explicitly documented; app makes requests at
                 user-controlled intervals (minimum 1 minute with
                 auto-check)

**Error Responses**:

  - 401: Invalid API key
  - 500: Server error
  - Network timeout: Handled by URLSession

---

## Implementation Notes

### Key Algorithms

**1. Bird Sorting**

```swift
  func sortBirds(
      _ birds: [BirdObservation],
      userLocation: CLLocation,
      forceSortMode: BirdSortMode? = nil
  ) -> [BirdObservation] 
  {
      let mode = forceSortMode ?? sortMode
  
      switch mode 
      {
        case .closest:
          return birds.sorted { bird1, bird2 in
              let loc1 = CLLocation(latitude: bird1.lat, longitude: bird1.lng)
              let loc2 = CLLocation(latitude: bird2.lat, longitude: bird2.lng)
              return userLocation.distance(from: loc1) < 
                         userLocation.distance(from: loc2)
          }
        case .mostRecent:
          return birds.sorted { $0.obsDt > $1.obsDt }
        case .largestCount:
          return birds.sorted { ($0.howMany ?? 0) > ($1.howMany ?? 0) }
      } // switch
  } // func sortBirds
```

**2. Speech Prioritization (Manual Fetch)**

```swift
  // Speak new birds first, then fill with closest birds

  let newBirdsSorted = 
    sortBirds(
        newOrChangedBirds, 
         userLocation: location, 
        forceSortMode: .closest )

  let unchangedBirdsSorted = 
    sortBirds(
        unchangedBirds, 
         userLocation: location, 
        forceSortMode: .closest )

  let birdsToSpeak = newBirdsSorted + unchangedBirdsSorted

  speakBirdsInOrder( 
      Array( birdsToSpeak.prefix( maxBirdsToSpeak ) ) )
```

### Performance Considerations

1. **API Call Frequency**:

   - Minimum auto-check interval: 1 minute
   - Manual fetches: No limit but require user action
   - Consider eBird server load

2. **Memory Management**:

   - Bird arrays limited by `maxBirdsToDisplay` (max 50)
   - Seen bird IDs grow over time but minimal memory impact
   - Use `[weak self]` in closures to prevent retain cycles

3. **Location Accuracy**:

   - `kCLLocationAccuracyKilometer` balances battery vs precision
   - Sufficient for bird observation use case
   - Reduces GPS power consumption

### Edge Cases Handled

  1. **No Location Available**:

     - Shows error message to user
     - Suggests checking Settings > Privacy
     - Doesn't crash or retry infinitely
  
  2. **No Birds Found**:

     - Shows "No birds found yet" placeholder
     - Provides instructions to fetch
     - Doesn't speak anything
  
  3. **API Key Invalid**:

     - User-friendly error message
     - Directs to Settings to update key
     - Doesn't expose technical details
  
  4. **Rapid Location Changes**:

     - Only resets when threshold exceeded
     - Prevents oscillation with small movements
     - Last known location only updated on reset
  
  5. **Speech During Fetch**:

     - Fetch button disabled while speaking
     - Prevents queuing multiple fetches
     - Clear visual feedback (grayed button)

---

## Future Enhancement Opportunities

  1. **Offline Mode**:

     - Cache observations for offline viewing
     - Queue API calls when network unavailable
  
  2. **Custom Bird Lists**:

     - Personal target species lists
     - Alert only for specific birds
  
  3. **Historical Tracking**:

     - Log all birds seen with timestamps
     - Export to CSV or share
  
  4. **Maps Integration**:

     - Show bird observations on map view
     - Cluster markers for dense areas
  
  5. **Photos & Media**:

     - Display bird photos from eBird
     - Link to Macaulay Library
  
  6. **Social Features**:

     - Share recent observations
     - Connect with other birders
  
  7. **Advanced Filters**:

     - Filter by rarity
     - Show only species not yet seen
     - Seasonal filters

---

## Testing Recommendations

### Unit Tests

  - BirdSortMode sorting algorithms
  - Distance calculations
  - Location-based ID generation
  - Speech text formatting

### Integration Tests

  - eBird API responses
  - Location permission flow
  - Background audio continuation
  - Settings persistence

### Manual Testing Scenarios

  1. Drive test with auto-check enabled
  2. Change search radius and verify results
  3. Test speech with different voice selections
  4. Verify background operation overnight
  5. Test with poor GPS signal
  6. Test with no network connection
  7. Verify location reset at threshold

### Accessibility Testing

  - VoiceOver navigation
  - Dynamic Type support
  - Color contrast for New badge
  - Button states clearly indicated

---

## Maintenance & Operations

### Logging Strategy

  - Print statements for debugging (development)
  - Key events logged:
    - Location updates
    - Distance calculations
    - Bird fetch results
    - Auto-check timer fires

### Monitoring Points

  - eBird API response times
  - Location fix acquisition time
  - Background execution duration
  - Speech synthesis completion

### Version Control

  - Git repository with semantic versioning
  - Tag releases (e.g., v1.0.0)
  - Document breaking changes in CHANGELOG

---

## Conclusion

Local Bird Reporter is a focused, user-friendly app for birders who
want automatic notifications of nearby bird observations while
traveling. The architecture prioritizes:

  - **Reliability**: Background operation with location tracking
  - **Simplicity**: Clean interface with essential features
  - **Configurability**: Extensive settings for different use cases
  - **Privacy**: Clear permissions and data handling

The design accommodates various birding scenarios from casual backyard
observation to dedicated birding road trips, with the flexibility to
adapt to user preferences through comprehensive settings.

-----
end
