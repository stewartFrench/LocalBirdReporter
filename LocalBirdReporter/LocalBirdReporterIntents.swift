//
//  LocalBirdReporterIntents.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 11/1/26.
//

import AppIntents
import CoreLocation

// ----------------------------------------
// Siri phrase: "Hey Siri, LocalBirdReporter"
// Toggles: starts a bird report, or stops one already speaking

struct FetchBirdsIntent: AppIntent
{
  static let title: LocalizedStringResource = "Fetch Local Birds"

  // ------------------------------
  // Run headlessly - no need to bring the app to the foreground

  static var supportedModes: IntentModes
  {
    .background

  } // supportedModes

  // ------------------------------

  @MainActor
  func perform() async throws -> some IntentResult
  {
    let viewModel = BirdReporterViewModel.shared

    if viewModel.isSpeaking
    {
      viewModel.stopSpeaking()

    } // if
    else
    {
      viewModel.fetchBirds()

    } // else

    return .result()

  } // perform

} // struct FetchBirdsIntent

// ----------------------------------------
// The four spoken adjustments Siri can make to search settings

enum SettingAdjustment: String, AppEnum
{
  case widen
  case narrow
  case longer
  case shorter

  static var typeDisplayRepresentation: TypeDisplayRepresentation
  {
    "Setting Adjustment"

  } // typeDisplayRepresentation

  static var caseDisplayRepresentations: [SettingAdjustment: DisplayRepresentation]
  {
    [
      .widen   : "widen",
      .narrow  : "narrow",
      .longer  : "longer",
      .shorter : "shorter"
    ]

  } // caseDisplayRepresentations

} // enum SettingAdjustment

// ----------------------------------------
// Siri phrase: "Hey Siri, LocalBirdReporter widen/narrow/longer/shorter"

struct AdjustSettingIntent: AppIntent
{
  static let title: LocalizedStringResource = "Adjust Bird Search Setting"

  // ------------------------------
  // Run headlessly - no need to bring the app to the foreground

  static var supportedModes: IntentModes
  {
    .background

  } // supportedModes

  @Parameter(title: "Adjustment")
  var adjustment: SettingAdjustment

  // ------------------------------

  static var parameterSummary: some ParameterSummary
  {
    Summary("\(\.$adjustment)")

  } // parameterSummary

  // ------------------------------

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog
  {
    let viewModel = BirdReporterViewModel.shared

    switch adjustment
    {
    case .widen:

      viewModel.searchRadiusKm = min(viewModel.searchRadiusKm + 1, 50)

    case .narrow:

      viewModel.searchRadiusKm = max(viewModel.searchRadiusKm - 1, 1)

    case .longer:

      viewModel.daysBack = min(viewModel.daysBack + 1, 30)

    case .shorter:

      viewModel.daysBack = max(viewModel.daysBack - 1, 1)

    } // switch

    if adjustment == .widen || adjustment == .narrow
    {
      let km = viewModel.searchRadiusKm

      if viewModel.distanceUnit == .miles
      {
        let miles = Int(Double(km) / 1.60934)

        return .result(
          value  : km,
          dialog : "Search radius is now \(miles) miles"
        )

      } // if

      return .result(
        value  : km,
        dialog : "Search radius is now \(km) kilometers"
      )

    } // if

    let days = viewModel.daysBack

    return .result(
      value  : days,
      dialog : "Showing birds from the last \(days) days"
    )

  } // perform

} // struct AdjustSettingIntent

// ----------------------------------------
// A favorited saved location, exposed to Siri as a finite, named option so
// voice phrases can reference it by name

struct FavoriteLocationEntity: AppEntity
{
  static var defaultQuery = FavoriteLocationQuery()

  // ------------------------------

  static var typeDisplayRepresentation: TypeDisplayRepresentation
  {
    "Favorite Location"

  } // typeDisplayRepresentation

  var id        : String
  var name      : String
  var siriName  : String
  var latitude  : Double
  var longitude : Double

  // ------------------------------
  // siriName (the shortcut name, falling back to the full name) is what
  // gets baked into the indexed phrase - not the full name

  var displayRepresentation: DisplayRepresentation
  {
    DisplayRepresentation(title: "\(siriName)")

  } // displayRepresentation

  // ------------------------------

  init(
    recentLocation: RecentLocation
  )
  {
    id        = recentLocation.id
    name      = recentLocation.name
    siriName  = recentLocation.siriName
    latitude  = recentLocation.latitude
    longitude = recentLocation.longitude

  } // init

} // struct FavoriteLocationEntity

// ----------------------------------------

struct FavoriteLocationQuery: EntityQuery
{

  // ------------------------------

  @MainActor
  func entities(
    for identifiers: [String]
  ) async throws -> [FavoriteLocationEntity]
  {
    BirdReporterViewModel.shared.recentLocations
      .filter { $0.isFavorite && identifiers.contains($0.id) }
      .map { FavoriteLocationEntity(recentLocation: $0) }

  } // entities

  // ------------------------------

  @MainActor
  func suggestedEntities() async throws -> [FavoriteLocationEntity]
  {
    BirdReporterViewModel.shared.recentLocations
      .filter { $0.isFavorite }
      .map { FavoriteLocationEntity(recentLocation: $0) }

  } // suggestedEntities

} // struct FavoriteLocationQuery

// ----------------------------------------
// Siri phrase: "Hey Siri, LocalBirdReporter <favorite location name>"
// Toggles like FetchBirdsIntent: stops if already speaking, otherwise
// switches to that saved location and starts a bird report there

struct FetchBirdsAtLocationIntent: AppIntent
{
  static let title: LocalizedStringResource = "Fetch Local Birds At Location"

  // ------------------------------
  // Run headlessly - no need to bring the app to the foreground

  static var supportedModes: IntentModes
  {
    .background

  } // supportedModes

  @Parameter(title: "Location")
  var location: FavoriteLocationEntity

  // ------------------------------

  static var parameterSummary: some ParameterSummary
  {
    Summary("\(\.$location)")

  } // parameterSummary

  // ------------------------------

  @MainActor
  func perform() async throws -> some IntentResult
  {
    let viewModel = BirdReporterViewModel.shared

    if viewModel.isSpeaking
    {
      viewModel.stopSpeaking()

    } // if
    else
    {
      viewModel.setManualLocation(
        CLLocation(
          latitude  : location.latitude,
          longitude : location.longitude
        ),
        name: location.name
      )

      viewModel.fetchBirds()

    } // else

    return .result()

  } // perform

} // struct FetchBirdsAtLocationIntent

// ----------------------------------------
// Siri phrase: "Hey Siri, LocalBirdReporter here"
// Toggles like FetchBirdsIntent: stops if already speaking, otherwise
// switches to current GPS location and starts a bird report there

struct FetchBirdsHereIntent: AppIntent
{
  static let title: LocalizedStringResource = "Fetch Local Birds Here"

  // ------------------------------
  // Run headlessly - no need to bring the app to the foreground

  static var supportedModes: IntentModes
  {
    .background

  } // supportedModes

  // ------------------------------

  @MainActor
  func perform() async throws -> some IntentResult
  {
    let viewModel = BirdReporterViewModel.shared

    if viewModel.isSpeaking
    {
      viewModel.stopSpeaking()

    } // if
    else
    {
      viewModel.clearManualLocation()
      viewModel.fetchBirds()

    } // else

    return .result()

  } // perform

} // struct FetchBirdsHereIntent

// ----------------------------------------
// Siri phrase: "Hey Siri, LocalBirdReporter settings"
// Speaks a quick summary of the settings that most affect what a
// fetch returns, via Siri's own dialog rather than the app's speech

struct ReportSettingsIntent: AppIntent
{
  static let title: LocalizedStringResource = "Report Current Settings"

  // ------------------------------
  // Run headlessly - no need to bring the app to the foreground

  static var supportedModes: IntentModes
  {
    .background

  } // supportedModes

  // ------------------------------

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog
  {
    let viewModel = BirdReporterViewModel.shared

    let radiusText: String

    if viewModel.distanceUnit == .miles
    {
      let miles = Int(Double(viewModel.searchRadiusKm) / 1.60934)
      radiusText = "\(miles) miles"

    } // if
    else
    {
      radiusText = "\(viewModel.searchRadiusKm) kilometers"

    } // else

    let autoCheckText = viewModel.isAutoCheckEnabled
      ? "Auto Check is on, every \(viewModel.checkIntervalMinutes) minutes"
      : "Auto Check is off"

    let locationText = viewModel.isUsingManualLocation
      ? "Using \(viewModel.manualLocationName ?? "a manual location")"
      : "Using your current GPS location"

    return .result(
      dialog: """
      Search radius is \(radiusText). Showing birds from the last \
      \(viewModel.daysBack) days. \(autoCheckText). \(locationText).
      """
    )

  } // perform

} // struct ReportSettingsIntent

// ----------------------------------------

struct LocalBirdReporterShortcuts: AppShortcutsProvider
{
  static var appShortcuts: [AppShortcut]
  {
    AppShortcut(
      intent           : FetchBirdsIntent(),
      phrases          : [
        "\(.applicationName)"
      ],
      shortTitle       : "Fetch Local Birds",
      systemImageName  : "bird"
    )

    AppShortcut(
      intent           : AdjustSettingIntent(),
      phrases          : [
        "\(.applicationName) \(\.$adjustment)"
      ],
      shortTitle       : "Adjust Bird Search",
      systemImageName  : "slider.horizontal.3"
    )

    AppShortcut(
      intent           : FetchBirdsAtLocationIntent(),
      phrases          : [
        "\(.applicationName) \(\.$location)"
      ],
      shortTitle       : "Fetch Birds At Location",
      systemImageName  : "mappin.and.ellipse"
    )

    AppShortcut(
      intent           : FetchBirdsHereIntent(),
      phrases          : [
        "\(.applicationName) here"
      ],
      shortTitle       : "Fetch Birds Here",
      systemImageName  : "location.fill"
    )

    AppShortcut(
      intent           : ReportSettingsIntent(),
      phrases          : [
        "\(.applicationName) settings"
      ],
      shortTitle       : "Report Current Settings",
      systemImageName  : "gearshape"
    )

  } // appShortcuts

} // struct LocalBirdReporterShortcuts
