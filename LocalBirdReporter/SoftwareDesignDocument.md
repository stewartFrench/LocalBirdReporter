# Software Design Document
## Local Bird Reporter iOS Application
## Built in Xcode as "LocalBirdReporter"

**Version:** 2.0

**Date:** November 2, 2026

**Author:** Stewart French, Claude Sonnet 5 by Anthropic

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
areas. The app automatically speaks to announce new birds
and maintains awareness of location changes.

### Key Capabilities

  - Fetches recent bird observations from eBird API based on current GPS
    location or a manually selected location
    
  - Supports an interactive map with satellite view for location selection

  - Supports quick re-selection from up to 10 recent locations, plus
    an unlimited number of favorited ("starred") locations that are
    never evicted by that cap

  - Supports Siri/App Intents voice control: start or stop a report,
    jump to a favorited location by name, jump to current GPS
    location, and adjust search radius or days-back, all by voice

  - Automatically checks for new birds at configurable intervals; this
    setting persists and resumes automatically on the next launch

  - Speaks the observation location (never raw GPS coordinates), then
    bird names and counts

  - Tracks which birds have been "seen" and speaks any new bird observations

  - Resets bird list when moving beyond a configurable distance
    threshold (GPS mode only)

  - Operates in background with location updates and speech announcements


### Target Platform

- iOS 26+
- iPhone (primary), iPad (supported)
- SwiftUI-based interface

---

## Architecture

### Design Pattern

The app follows the MVVM (Model-View-ViewModel) architecture pattern:

```
┌─────────────────────┐   ┌────────────────────────────┐
│     Views           │   │      App Intents           │  Siri entry point
│  ContentView        │   │  FetchBirdsIntent          │
│  SettingsView       │   │  AdjustSettingIntent       │
│  ChangeLocationView │   │  FetchBirdsAtLocationIntent│
│  AbouteBirdView     │   │  FetchBirdsHereIntent      │
└────────┬────────────┘   └────────────┬───────────────┘
         │                             │
         └──────────────┬──────────────┘
                        ▼
┌─────────────────────────────┐
│       ViewModel             │  @Observable
│  BirdReporterViewModel      │  - Business logic
│  (.shared singleton)        │  - State management
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
│  - RecentLocation           │  Favoritable location history
│  - FavoriteLocationEntity   │  AppEntity for Siri phrases
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

  6. **Shared ViewModel Singleton**: `BirdReporterViewModel.shared` lets
     App Intents act on the same live state (settings, `isSpeaking`,
     `recentLocations`) as the running UI, rather than a disconnected
     copy. `ContentView` holds a reference to the same shared instance

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
  7. Speaks the location of the first bird in the list, then speaks
     bird names using text-to-speech

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
  2. If distance > threshold (e.g., 3 km), reset:
     - Clear `seenBirdIds` set
     - Clear `birds` array
     - Update last known location to current position
  3. If distance < threshold, keep existing state

**Key Variables**:

  - `lastKnownLocation: CLLocation?` - Reference point for distance
     calculation
  - `resetDistanceKm: Int` - Configurable threshold (default 3 km)
  - Only updates last known location when reset occurs (not on every
    fetch)
  - Last known location is cleared on app launch to prevent GPS drift
    from showing false movement messages

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
- Configurable interval (default 2 minutes)
- Auto-check state persists in UserDefaults; it resumes automatically
  on launch if it was running when the app was last closed, and is
  OFF by default on a true first launch

### 5. Recent Locations & Favorites

**Purpose**: Let the user quickly return to previously used manual
             locations without re-searching or re-tapping the map,
             and let specific locations persist indefinitely so they
             can be attached to a stable Siri voice phrase

**Flow**:

  1. Every time `setManualLocation(_:name:)` is called (via search
     result, map tap, or recent-location selection), the location is
     recorded via `addRecentLocation(name:location:)`
  2. Any existing entry with the same name is removed first so the
     location moves to the front rather than duplicating; its
     `isFavorite` and `siriShortcutName` are carried forward onto the
     new entry so re-selecting a location (by hand or via Siri) never
     silently erases either
  3. `trimRecentLocations()` then keeps at most 10 *non-favorite*
     entries, newest first — favorited entries are exempt from this
     cap and are never evicted, no matter how many temporary
     locations get visited afterward
  4. The list persists in UserDefaults (JSON-encoded) and reloads on
     launch

**Favorites** (the star button on each row):

  - `toggleFavoriteLocation(_:)` flips `isFavorite` on a saved entry,
    re-applies `trimRecentLocations()`, and calls
    `LocalBirdReporterShortcuts.updateAppShortcutParameters()` so Siri
    re-indexes immediately
  - Only favorited locations are exposed to Siri (see App Intents
    below) — the non-favorite recent list churns too often to make a
    stable voice-phrase set

**Siri Shortcut Names** (the ⓘ button, shown only on favorited rows):

  - Tapping it opens an alert (pre-filled with the current shortcut
    name, or the full name if none is set) to type a shorter,
    voice-friendlier name — e.g. "Hagerman" instead of "Hagerman
    National Wildlife Refuge"
  - `setSiriShortcutName(_:for:)` stores it as `siriShortcutName` on
    the matching `RecentLocation` (blank input clears it back to the
    full name) and calls `updateAppShortcutParameters()`
  - `RecentLocation.siriName` resolves to `siriShortcutName ?? name` —
    this is what gets interpolated into the indexed Siri phrase; the
    full `name` is unaffected and still used for display and for
    `setManualLocation`
  - Siri's matching of a custom per-app entity name is fairly literal,
    not fuzzy like a built-in domain (Music, Maps) — a short, memorable
    name works noticeably better than hoping a partial match on the
    full name resolves. It can also lose to Siri's own knowledge-base
    recognition if the chosen name collides with a well-known public
    figure or place (observed with "Bob Woodruff" matching the ABC
    News correspondent); picking a more distinctive name works around
    this, since there's no API for an app to out-prioritize Siri's own
    entity recognition

**UI Behavior** (in ChangeLocationView):

  - Recent locations are shown when the search field is not focused
  - Live search completions replace them once the field gains focus
    and has text
  - Tapping a recent location immediately sets it as the manual
    location, identical to selecting a live search result

**Key Components**:

- `RecentLocation` struct in BirdReporterViewModel
- `recentLocations: [RecentLocation]` persisted property
- `addRecentLocation(name:location:)`, `toggleFavoriteLocation(_:)`,
  `setSiriShortcutName(_:for:)`, `trimRecentLocations()` in
  BirdReporterViewModel

### 6. App Intents / Siri Voice Control

**Purpose**: Let Siri run core actions by voice without opening the app

**Setup**: All phrases include `\(.applicationName)` (the app's actual
          display name, "LocalBirdReporter") per App Shortcuts
          requirements — defined in `LocalBirdReporterIntents.swift`,
          compiled directly into the main app target (no separate App
          Intents extension), so intents run in the same process as
          the running app and share its live `BirdReporterViewModel`

**Intents** (all run `supportedModes: .background` — no UI is shown):

  1. **`FetchBirdsIntent`** — phrase: "Hey Siri, LocalBirdReporter".
     If `isSpeaking`, stops speaking; otherwise calls `fetchBirds()`
     exactly as the "Fetch Local Birds" button does (so Auto Check's
     on/off state is never touched by this)

  2. **`AdjustSettingIntent`** — phrase: "Hey Siri, LocalBirdReporter
     widen/narrow/longer/shorter". One `AppEnum` (`SettingAdjustment`)
     parameter expands into all four phrases from a single template.
     `widen`/`narrow` adjust `searchRadiusKm` by 1 (clamped 1...50);
     `longer`/`shorter` adjust `daysBack` by 1 (clamped 1...30). Each
     returns a spoken dialog confirmation (e.g. "Search radius is now
     6 kilometers"), converting to miles for display if that's the
     user's unit

  3. **`FetchBirdsAtLocationIntent`** — phrase: "Hey Siri,
     LocalBirdReporter \<favorite location name\>". Takes a
     `FavoriteLocationEntity` parameter, backed by `FavoriteLocationQuery`
     (an `EntityQuery` scoped to `recentLocations.filter { $0.isFavorite }`,
     implementing both `entities(for:)` and `suggestedEntities()` so
     the Shortcuts-app picker isn't empty). If `isSpeaking`, stops;
     otherwise calls `setManualLocation(name:location:)` for that
     location then `fetchBirds()`

  4. **`FetchBirdsHereIntent`** — phrase: "Hey Siri, LocalBirdReporter
     here". If `isSpeaking`, stops; otherwise calls
     `clearManualLocation()` (switch to GPS) then `fetchBirds()`

**`LocalBirdReporterShortcuts`**: the `AppShortcutsProvider` registering
  all four as zero-setup App Shortcuts (4 of the 10-shortcut-per-app
  cap). `updateAppShortcutParameters()` must be called whenever the
  favorited-location set or a shortcut name changes, or Siri keeps
  matching against a stale snapshot

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

      var spokenLocName: String
      {
          // Strips a trailing "lat, lng" coordinate pair (with or
          // without parentheses) that eBird appends to locName for
          // personal (non-hotspot) locations, so coordinates are
          // never spoken
      }
  } // struct
```

**Note**: eBird returns raw coordinates appended to `locName` for
          personal/non-hotspot observation locations — sometimes
          parenthesized ("Name (32.97, -96.72)"), sometimes not
          ("Name, City US-TX 32.97, -96.72"). `spokenLocName` strips
          either form via regex before the name is ever passed to
          speech. Display (the blue location line in the bird list)
          still shows the raw, unstripped `locName`.

### BirdSortMode
```swift
  enum BirdSortMode: String, CaseIterable, Codable 
  {
    case closest      = "Closest"
    case mostRecent   = "Most Recently Reported"
    case largestCount = "Largest Number"
  }
```

**Note**: Default sort mode is "Largest Number" and persists between app
          restarts.

### DistanceUnit
```swift
  enum DistanceUnit: String, CaseIterable, Codable 
  {
      case kilometers = "Kilometers"
      case miles      = "Miles"
  }
```

### RecentLocation
```swift
  struct RecentLocation: Codable, Identifiable
  {
      let name: String
      let latitude: Double
      let longitude: Double
      var isFavorite: Bool
      var siriShortcutName: String?     // nil = use full name for Siri

      var id: String
      {
          "\(name)_\(latitude)_\(longitude)"  // Unique ID for SwiftUI
      }

      var coordinate: CLLocationCoordinate2D
      {
          CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      }

      var siriName: String
      {
          siriShortcutName ?? name   // What Siri actually matches against
      }
  } // struct
```

**Note**: Up to 10 non-favorite entries are kept, newest first;
          favorited entries are never evicted by that cap. Persisted
          as JSON in UserDefaults under the `recentLocations` key.
          Custom `Decodable` decoding (`decodeIfPresent` for
          `isFavorite`/`siriShortcutName`) lets entries saved before
          either field existed decode with `false`/`nil` instead of
          failing.

### FavoriteLocationEntity

An `AppEntity` (in `LocalBirdReporterIntents.swift`) wrapping a
favorited `RecentLocation` for use as a Siri-matchable parameter. Its
`displayRepresentation` uses `siriName` (the shortcut name, falling
back to the full name) — that's the string actually baked into the
indexed Siri phrase, not the full location name. Backed by
`FavoriteLocationQuery: EntityQuery`, scoped to
`recentLocations.filter { $0.isFavorite }`.

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
      maxResults: Int = 10,
      distanceKm: Int = 5
  ) async throws -> [BirdObservation]
```

**Parameters**:

  - `lat/lng`: GPS coordinates
  - `back`: Days back to search
  - `maxResults`: Maximum observations to return
  - `dist`: Search radius in kilometers

**Note**: The default parameter values above are rarely used in
          practice — `BirdReporterViewModel.fetchBirds()` always calls
          this with the user's current `daysBack`, `maxBirdsToDisplay`,
          and `searchRadiusKm` settings explicitly.

**Error Handling**:

  - Invalid eBird key: Shows user-friendly error message ("Invalid
    eBird key...") and clears the displayed bird list via
    `birds.removeAll()` — previously the stale list from before the
    key went bad stayed on screen with no visible error, because
    the status area checked `distanceMessage` before `errorMessage`
    (now fixed: error takes priority)
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
  - Duplicate voice names filtered out
  - Mixing with background audio (silent audio)
  - AVSpeechSynthesizer for speech synthesis
  - Optional "No new birds" announcement

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
  // Returns deduplicated list of English voices
```

**Note**: `SpeechService` exposes a `speakBirds(_:)` convenience method,
          but it is currently unused — `BirdReporterViewModel` builds
          its own speech strings (in `speakBirdsInOrder` and
          `speakNewBirdsOnly`) and calls `speak(_:)` directly, so it
          can include the location announcement and count/"New"
          phrasing described below.

**Speech Patterns** (built in `BirdReporterViewModel`):

  - **All birds new**: "New birds found at [location],, Bird Name,
    Count,, ..."
  - **Mixed new/old**: "At [location],, Bird Name, Count,, Bird Name,
    Count, New,, ..."
  - **No new birds** (auto-check only, if "Announce 'No new birds'"
    is enabled): "No new birds"

  `[location]` is the `spokenLocName` (coordinate-stripped, see
  BirdObservation above) of the first bird in the (sorted) list being
  spoken — not the user's GPS or manual location name. If eBird
  returns zero observations, nothing is spoken (there is no bird data
  to pull a location name from).

---

## User Interface

### ContentView

**Main Screen Components**:

  1. **Header**

     - App title: "Local Bird Reporter"
     - "Powered by eBird" link (opens AbouteBirdView)
     - Settings gear icon (top-right)
     - Manual location name display (if set, in orange) or "Using
       current GPS location" (secondary color)
     - Location reset button (location.fill icon) next to the
       location text, disabled unless a manual location is set;
       taps `clearManualLocation()` to return to GPS mode
     - Sort mode display: "Sorted by: [mode]"
  
  2. **Status Area**

     - Loading indicator when fetching
     - Error messages in red — checked *before* the distance message,
       so a failed fetch (e.g. invalid eBird key) is never masked by
       a leftover "Moved X.X km" message
     - Distance message: "Moved X.X km (< Y km threshold)"
     - Fixed height: 44pt
  
  3. **Bird List**

     - Scrollable list of observations
     - Automatically scrolls to top after each fetch
     - Automatically scrolls to top when sort mode changes
     - New birds shown first with 🆕 badge
     - Tappable bird name → opens eBird species page
     - Tappable location → opens Apple Maps
     - Yellow highlight for new birds
     - Displays: name, count, location, date/time
  
  4. **Action Buttons**

     - "Stop Speaking" (red when active, gray when disabled)
     - "Fetch Local Birds" (blue, disabled when loading or speaking)

### SettingsView

**Organized into sections** (most-used items at top):

  1. **Search & Display**
  
     - Display: X birds (stepper, 1-50)
     - Show birds from last: X days (stepper, 1-30)
     - Search radius: X km/mi (stepper, 1-50)
     - Sort by (picker: Closest/Most Recent/Largest Count)

  2. **Location**
  
     - Change Location button (opens ChangeLocationView)
     - Use Current Location button (disabled in GPS mode); calls
       `clearManualLocation()`
     - Location status display:
       - "Currently: [location name]" (if manual location set)
       - "Using manual location" (if set but no name)
       - "Using current GPS location" (if GPS mode)
  
  3. **Auto Check**
  
     - Check every X minutes (stepper, 1-120)
     - Enable Auto Check (toggle)
     - Announce "No new birds" (toggle)
  
  4. **Speech**
  
     - Speak: X birds (stepper, 0-30, 0=off)
  
  5. **Voice**
  
     - Voice (picker of deduplicated English voices)
  
  6. **Distance Units**
  
     - Distance units (picker: Kilometers/Miles)
     - Mark all birds New after moving: X km/mi (stepper, 1-50)

  7. **eBird Key**

     - Secure field for the eBird key — both the section header and
       the SecureField's own inline placeholder read "eBird Key" (no
       "API" wording anywhere user-facing); the UserDefaults storage
       key remains `eBirdAPIKey` internally
     - Link to obtain a free eBird key
     - "Reset to Defaults" below is disabled and dimmed while this
       field has keyboard focus (`@FocusState`), so it can't be
       tapped accidentally right after entering a new key

  8. **Reset**

     - "Reset to Defaults" destructive button
     - Confirmation dialog before calling `resetToDefaults()`
     - Does not reset the eBird key

### ChangeLocationView

**Map-Based Location Picker**:

  1. **Search Field**
  
     - Displays current location name on open
     - Live search with MKLocalSearchCompleter
     - Clear button (x) with auto-focus
     - Magnifying glass icon to trigger search
     - Current location icon (arrow pointing up-right)
     - Fixed light-gray box background (`Color(white: 0.9)`) with
       fixed `.black` text — intentionally non-adaptive to dark mode,
       since the adaptive `systemGray6` background used previously
       turned nearly black in dark mode and made the search box
       indistinguishable from the surrounding sheet background

  2. **Recent Locations List**

     - Shown below the search bar when the search field is not
       focused and `viewModel.recentLocations` is non-empty — this is
       the primary content of the view now that the inline map
       preview has been removed (see "View on Map button" below), so
       its `List` frame height was expanded from 150pt to 350pt
     - Each row has three tappable elements: a star button (toggles
       `isFavorite`, filled yellow when favorited), the clock-icon
       name button (calls `selectRecentLocation(_:)`, same as
       selecting a live search result), and — only on favorited
       rows — a trailing ⓘ button that opens the Siri Shortcut Name
       alert (see Core Features → Recent Locations & Favorites)
     - Replaced by live search completions once the field gains
       focus and has text

  3. **View on Map button**

     - Positioned just above the "Done" button, below a flexible
       `Spacer()` (so it stays pinned near the bottom even when the
       lists above are short or empty)
     - Replaces the old always-visible small map preview — tapping it
       sets `showingFullScreenMap = true`, opening the same
       full-screen map sheet described below; map interaction itself
       is unchanged, it's just no longer shown inline by default
     - The now-unused `TappableMapView` (the small preview's
       `UIViewRepresentable` + `Coordinator`) was removed along with
       the inline preview

  4. **Full-Screen Map**
  
     - Interactive map with pan and zoom
     - Tap anywhere to select location
     - Map type toggle button
     - Close button (x) in top-right corner
     - Immediately sets manual location on selection
     - iOS 26 MapKit APIs (MKReverseGeocodingRequest)
  
  5. **Workflow**
  
     - Selecting location immediately sets it (no "Go There" button)
     - "Done" button dismisses view
     - Current location icon clears manual location and returns to GPS mode
     - Dismissing returns to Settings or main view
  
  6. **Location Modes**
  
     - **GPS Mode**: Uses current device location, updates with movement
     - **Manual Mode**: Fixed location, ignores device movement
     - Distance-based reset only applies in GPS mode

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
|     | Int      |   10   | Birds announced        |
| `checkIntervalMinutes`
|     | Int      |    2   | Auto-check frequency   |
| `resetDistanceKm`
|     | Int      |    3   | Distance threshold     |
| `searchRadiusKm`
|     | Int      |    3   | eBird search radius    |
| `daysBack`
|     | Int      |    7   | How far back to search |
| `birdSortMode`
|     | Codable  | .largestCount | Sorting preference   |
| `distanceUnit`
|     | Codable  | .kilometers | Display units     |
| `selectedVoiceIdentifier`
|     | String?  |   nil  | TTS voice              |
| `seenBirdIds`
|     | [String] |    []  | Tracked bird IDs       |
| `lastKnownLatitude`
|     | Double?  |   nil  | Last reset location    |
| `lastKnownLongitude`
|     | Double?  |   nil  | Last reset location    |
| `hasLaunchedBefore`
|     | Bool     |  false | First launch flag      |
| `announceNoNewBirds`
|     | Bool     |  false | Speak "No new birds"   |
| `isAutoCheckEnabled`
|     | Bool     |  false | Auto Check on/off; resumed automatically on launch |
| `recentLocations`
|     | Codable  |    []  | Up to 10 non-favorite + unlimited favorited manual locations, newest first |
|-----|----------|--------|------------------------|

**Note**: Manual location selection itself (`manualLocation`,
          `manualLocationName`, `isUsingManualLocation`) is
          **in-memory only** and is not persisted — every app launch
          starts in GPS mode. `recentLocations` exists specifically to
          make it quick to re-select a previous manual location after
          relaunching. `lastKnownLatitude`/`lastKnownLongitude` are
          written during a session but always cleared (not read back)
          on the next launch, for the same reason described under
          Location-Based Reset. The displayed bird list (`birds`) is
          likewise **not persisted** — it intentionally no longer
          survives a relaunch (see Data Persistence below); only
          `seenBirdIds` (which birds have already been reported)
          persists.

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

1. **Location Source Selection**:

   - If manual location set: Use fixed coordinates (ignore GPS)
   - If GPS mode: Request fresh location via `requestLocation()`
   - Wait up to 5 seconds for GPS fix
   - Use `startUpdatingLocation()` for continuous updates

2. **Distance Calculation** (GPS mode only):

```swift
  let distanceInMeters = location.distance(from: lastLocation)
  let distanceInKm = distanceInMeters / 1000.0
```

3. **Reset Logic** (GPS mode only):

   - Only update `lastKnownLocation` when threshold exceeded
   - Prevents incremental drift (small movements don't update reference)
   - Manual location mode: No distance tracking or reset

4. **Manual Location Features**:

   - Pin specific location (e.g., wildlife refuge)
   - Monitor remote location from anywhere
   - Interactive map with search and tap-to-select
   - Standard and satellite/hybrid map views
   - Reverse geocoding for location names
   - Quick re-selection from up to 10 recently used locations, plus
     any number of favorited locations
   - Session-only: resets to GPS mode on every app launch (recent
     locations make it fast to re-pin a favorite spot afterward)

---

## Speech & Audio

### Text-to-Speech Engine

Uses AVFoundation's AVSpeechSynthesizer

**Speech Formatting**:

  - Bird names: As provided by eBird
  - Counts: Numeric value after name
  - Separators: ",, " (double comma for natural pause)
  - Location announcement: always spoken first, using the
    coordinate-stripped `spokenLocName` of the first bird in the list
  - Prefix: "New birds found at [location]" when all birds are new,
    otherwise "At [location]"
  - Suffix: ", New" for individual new birds in a mixed list

**Example Speech Strings**:

```
  "New birds found at Oak Point Park,, Wood Duck, 2,, Barn Swallow, 8,, " +
  "Scissor-tailed Flycatcher, 1"

  "At Oak Point Park,, Wood Duck, 2,, Barn Swallow, 8, New,, Northern Cardinal, 4"

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
  - Last known location coordinates (written but not restored — see
    Settings & Configuration note)
  - Recent locations (JSON encoded, up to 10 non-favorite + unlimited
    favorited, including each one's `isFavorite`/`siriShortcutName`)
  - Auto Check enabled flag

**In-Memory Only**:

  - Current bird observations array (`birds`) — **intentionally not
    persisted**; every launch starts with an empty list rather than
    showing whatever was on screen when the app was last force-quit
    (previously `saveBirds()`/`savedBirds` persisted and restored
    this; both were removed, along with the five call sites that
    wrote to it, since nothing read it back anymore once launch
    restoration was removed)
  - Manual location (coordinate, name, and the flag that enables it)
    — intentionally not persisted; resets to GPS mode every launch
  - Location manager state
  - Speech synthesizer state
  - Timer reference

### Save Points

  1. **After Each Fetch**:
  
     - `saveSeenBirdIds()` - Convert set to array and store
  
  2. **On Setting Changes**:

     - Immediate save via `didSet` property observers
     - No explicit save call needed
  
  3. **On Location Reset**:

     - Save new last known location coordinates
     - Save cleared seen bird IDs

  4. **On Manual Location Set**:

     - `addRecentLocation(name:location:)` updates and re-saves
       `recentLocations`, preserving `isFavorite`/`siriShortcutName`
       from any existing entry with the same name

  5. **On Auto Check Start/Stop**:

     - `startAutoCheck()`/`stopAutoCheck()` immediately persist
       `isAutoCheckEnabled`

  6. **On Favorite Toggle / Shortcut Name Change**:

     - `toggleFavoriteLocation(_:)` and `setSiriShortcutName(_:for:)`
       re-save `recentLocations` and call
       `LocalBirdReporterShortcuts.updateAppShortcutParameters()` so
       Siri re-indexes immediately

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

      // Restore recent locations
      if let savedRecentLocations = UserDefaults.standard.data(...),
         let decodedLocations = try? JSONDecoder().decode(...)
      {
          recentLocations = decodedLocations
      }

      // Note: the bird list is NOT restored here - every launch
      // starts with an empty `birds` array (see In-Memory Only above)

      // Resume Auto Check if it was running last session
      if UserDefaults.standard.object(forKey: "isAutoCheckEnabled") as? Bool ?? false
      {
          startAutoCheck()
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
  - `back`      : Days back (1-30, set from the "Show birds from
                  last" setting)
  - `dist`      : Distance in km (1-50, set from "Search radius")
  - `maxResults`: Maximum results (1-50, set from "Display" setting)

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
  // Speak new birds first, then unchanged birds
  // Both use the user's selected sort mode (not forced to closest)

  let newBirdsSorted = 
    sortBirds(
        newOrChangedBirds, 
         userLocation: location )

  let unchangedBirdsSorted = 
    sortBirds(
        unchangedBirds, 
         userLocation: location )

  let birdsToSpeak = newBirdsSorted + unchangedBirdsSorted

  speakBirdsInOrder( 
      Array( birdsToSpeak.prefix( maxBirdsToSpeak ) ) )

  // Inside speakBirdsInOrder: always announce the location of the
  // first bird, prefixed with "New birds found at" if every bird in
  // the list is new, or just "At" otherwise

  let firstLocationName = birds[0].spokenLocName

  if allBirdsAreNew
  {
      speechParts.append("New birds found at \(firstLocationName)")
  }
  else
  {
      speechParts.append("At \(firstLocationName)")
  }
```

**Note**: Speech and display now use the same sort order (user's selected
          preference), ensuring consistency. The same location-first
          pattern is used in `speakNewBirdsOnly` for auto-check.

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
     - Doesn't speak anything (there's no bird data to pull a
       location name from, so even the location isn't announced)
  
  3. **eBird Key Invalid**:

     - User-friendly error message ("Invalid eBird key...")
     - Clears the displayed bird list (`birds.removeAll()`) so stale
       results don't linger alongside the error
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
  
  6. **Manual Location Mode**:
  
     - No distance tracking when manual location set
     - Resets to GPS mode on every app launch (not persisted);
       `recentLocations` lets you quickly re-pin it afterward
     - Can monitor remote locations from anywhere
     - Clear visual indicator (orange text on main view)

  7. **Auto Check Across Launches**:

     - State persists; resumes automatically if it was on when the
       app was last closed
     - On a true first launch (no saved value yet), defaults to OFF

---

## Recent Updates (November 2026)

  1. **App Intents / Siri Voice Control**:

     - Four zero-setup App Shortcuts added: start/stop a bird report
       ("Hey Siri, LocalBirdReporter"), widen/narrow/longer/shorter
       search-setting adjustments with spoken confirmation, jump to a
       favorited location by name, and jump to current GPS location
       ("...here")
     - `BirdReporterViewModel.shared` singleton added so intents share
       the running app's live state instead of a disconnected copy
     - See Core Features → App Intents / Siri Voice Control for details

  2. **Favorites & Siri Shortcut Names**:

     - Recent-locations cap raised from 5 to 10, and favorited
       ("starred") locations are now exempt from that cap entirely —
       they persist until unfavorited, specifically so they can be
       attached to a stable Siri phrase even while temporary locations
       churn through the capped list
     - Each favorited location can have a short "Siri shortcut name"
       set via a new ⓘ button, since Siri's matching on a custom
       per-app entity is fairly literal (not fuzzy like Music/Maps) —
       a full name like "Hagerman National Wildlife Refuge" often
       doesn't resolve from a short spoken phrase, but a registered
       short name does
     - Fixed a data-loss bug where re-selecting a location (by hand
       or via its own Siri shortcut) silently reset its favorite
       status and shortcut name, because `addRecentLocation` rebuilt
       the entry from scratch instead of preserving both fields

  3. **ChangeLocationView Redesign**:

     - Removed the always-visible inline map preview; replaced with a
       "View on Map" button (pinned just above "Done") that opens the
       same full-screen map as before — map interaction itself is
       unchanged
     - Recent Locations list expanded from 150pt to 350pt tall, since
       it's now the primary content of the view

  4. **Bird List No Longer Persisted Across Launches**:

     - Previously the last-fetched bird list was saved and restored
       on next launch; now every launch starts with an empty list,
       matching how "seen" tracking and manual location already work
     - `saveBirds()`/`savedBirds` and all five call sites removed

  5. **GPS Coordinates Never Spoken**:

     - eBird appends raw coordinates to `locName` for personal
       (non-hotspot) observation locations, with or without
       parentheses — `BirdObservation.spokenLocName` strips either
       form via regex before speech, so coordinates are never
       announced

  6. **Error Message Visibility Fix**:

     - The status area checked `distanceMessage` before
       `errorMessage`, so a failed fetch (e.g. invalid key) silently
       showed stale distance text instead of the error. Error now
       takes priority

  7. **"eBird Key" Wording Completed**:

     - The SecureField's own inline placeholder (previously still
       "API Key" despite the section header already saying "eBird
       Key") now also reads "eBird Key," and error messages say
       "Invalid eBird key" instead of "Invalid API key"
     - "Reset to Defaults" is disabled/dimmed while the eBird Key
       field has focus, to prevent an accidental tap right after
       entering a new key

## Previous Updates (October 2026)

  1. **Recent Locations**:

     - Quick-select list of the 5 most recently used manual
       locations, persisted across launches
     - Shown in ChangeLocationView when the search field isn't
       focused; replaced by live search results once you start typing

  2. **Dark Mode Fix**:

     - ChangeLocationView's search field used an adaptive gray
       background that turned nearly black in dark mode, making the
       box indistinguishable from the sheet behind it
     - Changed to a fixed light-gray background with fixed dark text,
       readable in both appearances

  3. **Spoken Location Announcements**:

     - Both manual "Fetch Local Birds" and auto-check now announce
       the observation location before the bird list, every time
       there's something to speak — not just when all birds are new

  4. **Auto Check Persistence**:

     - Auto Check on/off state now persists in UserDefaults and
       resumes automatically on the next launch if it was running
       when the app was last closed

  5. **eBird Terminology Simplified**:

     - Settings section header changed from "eBird API" to
       "eBird Key"
     - "Get a free API key" link changed to "Get a free eBird key"
     - Aimed at users unfamiliar with the term "API"

## Previous Updates (August 2026)

  1. **Manual Location Selection**:

     - Map-based location picker with search
     - Satellite/hybrid map view toggle
     - Remote location monitoring
     - Reverse geocoding for location names
  
  2. **iOS 26 Compatibility**:

     - Updated to MKReverseGeocodingRequest (deprecated CLGeocoder)
     - Uses MKAddressRepresentations for location names
     - Removed deprecated placemark API usage
  
  3. **UI Improvements**:

     - Settings reorganized (most-used items at top)
     - Scroll-to-top after fetch and sort changes
     - Manual location name display on main view
     - Editable search field with clear button
     - Map type toggle on both small and full-screen maps
  
  4. **Speech Enhancements**:

     - Cleaned up voice list (no duplicate names)
     - Optional "No new birds" announcement
     - Speech can be disabled (set to 0)
     - Speech and display use same sort order
  
  5. **Sort Mode Updates**:

     - Default changed to "Largest Number"
     - "Closest to Me" renamed to "Closest"
     - Sort mode persists between app restarts
     - Triggers automatic scroll-to-top on change
  
  6. **Text Updates**:

     - "Supported by eBird" changed to "Powered by eBird"

## Future Enhancement Opportunities

  1. **App Intents Follow-Ons**

     - Connect the Shortcuts to Apple CarPlay
     - Have Siri change more Settings beyond search radius/days-back
     - A way to let Siri disambiguate or list available favorited
       locations by voice ("What locations do I have saved?")

  2. eBird Key Acquisition

     - Detect successful eBird signup and the "confirm your email screen"
     - Tell the user to go click the link in their email
     - When they come back to the app, try to load the profile page or something to see if they activated the account
     - Load API generation page automatically, maybe even prefill the Organization Project name, and Usage description for them

  3. **Keeping Records**:

     - Keep an app-local list of timestamped birds and their locations for quick reference
     - Prepare a pdf file with timestamps and active links to eBird for each bird, and Apple Maps for their locations
  
  4. **Enhanced Maps**:

     - Show bird observations as pins on map
     - Cluster markers for dense areas
     - Trail/hotspot overlays
     - Have Apple Maps automatically give driving directions to a reported bird location
  
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
  8. Set 11+ non-favorite locations via Change Location; verify the
     Recent Locations list caps at 10, newest first, and survives
     relaunch — then favorite one near the cap boundary and verify it
     is never evicted regardless of how many more locations are added
  9. Verify Change Location's search field is readable in both Light
     and Dark Mode
  10. Enable Auto Check, force-quit the app, relaunch, and verify it
      resumes automatically
  11. Verify spoken announcements lead with the location name on
      both manual fetch and auto-check, and that raw GPS coordinates
      are never spoken for a personal (non-hotspot) eBird location
  12. Force-quit the app after a fetch with birds displayed; relaunch
      and verify the bird list starts empty (not restored)
  13. Favorite a location, set a Siri shortcut name via the ⓘ button,
      then re-select that location (by tapping it, or via its own
      Siri phrase) and verify the shortcut name is still set
      afterward — this previously got silently wiped
  14. Test each App Intent via Siri: "Hey Siri, LocalBirdReporter"
      (start, then say it again mid-speech to verify it stops),
      "...widen"/"narrow"/"longer"/"shorter" (verify spoken
      confirmation), "...\<favorited shortcut name\>", and "...here"
  15. Verify the ⓘ shortcut-name button only appears on favorited
      (starred) rows, not on plain recent ones

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

  - eBird response times
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
