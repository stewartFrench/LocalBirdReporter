//
//  ChangeLocationView.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/13/26.
//

import SwiftUI
import MapKit
import Observation

// ----------------------------------------

struct ChangeLocationView: View
{
  @Environment(\.dismiss) var dismiss
  var viewModel       : BirdReporterViewModel
  var dismissSettings : (() -> Void)?

  @State private var searchText           = ""
  @State private var searchResults        : [MKLocalSearchCompletion] = []
  @State private var selectedCoordinate   : CLLocationCoordinate2D?
  @State private var selectedLocationName : String?
  @State private var region               = MKCoordinateRegion(
    center : CLLocationCoordinate2D(
      latitude  : 37.7749,
      longitude : -122.4194
    ),
    span   : MKCoordinateSpan(
      latitudeDelta  : 0.05,
      longitudeDelta : 0.05
    )
  )
  @State private var showingFullScreenMap = false
  @State private var mapType              : MKMapType = .standard
  @State private var searchCompleter      = LocationSearchCompleter()

  @FocusState private var isSearchFieldFocused : Bool

  // ------------------------------

  var body: some View
  {
    NavigationView
    {
      VStack(spacing: 0)
      {

                // Search bar with icons

        HStack
        {
          Button(
            action:
            {
              if !searchText.isEmpty
              {

                        // Perform search

                searchCompleter.searchQuery = searchText

              } // if

            } // action
          )
          {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.blue)

          } // Button
          .buttonStyle(.borderless)

          Button(
            action:
            {
              useCurrentLocation()

            } // action
          )
          {
            Image(systemName: "location.north.fill")
              .foregroundColor(.blue)

          } // Button
          .buttonStyle(.borderless)

          HStack
          {
            TextField(
              "Search location",
              text: $searchText
            )
            .textFieldStyle(.plain)
            .foregroundColor(.black)
            .focused($isSearchFieldFocused)
            .onChange(of: searchText)
            {
              oldValue, newValue in

              searchCompleter.searchQuery = newValue

            } // onChange

            if !searchText.isEmpty
            {
              Button(
                action:
                {
                  searchText = ""
                  searchCompleter.results = []
                  isSearchFieldFocused = true

                } // action
              )
              {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.gray)

              } // Button
              .buttonStyle(.borderless)

            } // if

          } // HStack
          .padding(8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(white: 0.9))
          )

        } // HStack
        .padding()

                // Recent locations

        if !isSearchFieldFocused && !viewModel.recentLocations.isEmpty
        {
          List(viewModel.recentLocations)
          {
            recent in

            Button(
              action:
              {
                selectRecentLocation(recent)

              } // action
            )
            {
              HStack
              {
                Image(systemName: "clock.arrow.circlepath")
                  .foregroundColor(.secondary)
                Text(recent.name)
                  .foregroundColor(.primary)

              } // HStack

            } // Button

          } // List
          .frame(maxHeight: 150)

        } // if

                // Search results

        if isSearchFieldFocused && !searchCompleter.results.isEmpty && !searchText.isEmpty
        {
          List(
            searchCompleter.results,
            id: \.self
          )
          {
            result in

            Button(
              action:
              {
                selectSearchResult(result)

              } // action
            )
            {
              VStack(alignment: .leading)
              {
                Text(result.title)
                  .foregroundColor(.primary)
                Text(result.subtitle)
                  .font(.caption)
                  .foregroundColor(.secondary)

              } // VStack

            } // Button

          } // List
          .frame(maxHeight: 200)

        } // if

                // Map with tap to expand to full screen

        ZStack(alignment: .topTrailing)
        {
          TappableMapView(
            region               : $region,
            selectedCoordinate   : $selectedCoordinate,
            mapType              : $mapType,
            onCoordinateSelected :
            {
              coordinate in

              reverseGeocode(coordinate)

            } // onCoordinateSelected
          )
          .onTapGesture
          {
            showingFullScreenMap = true

          } // onTapGesture

                  // Map type toggle button

          Button(
            action:
            {
              mapType = mapType == .standard ? .hybrid : .standard

            } // action
          )
          {
            Image(systemName: mapType == .standard ? "map" : "map.fill")
              .padding(8)
              .background(Color.white.opacity(0.9))
              .cornerRadius(8)
              .shadow(radius: 2)

          } // Button
          .padding(8)

        } // ZStack

        Spacer()

                // Done button

        HStack
        {
          Spacer()

          Button("Done")
          {
            dismiss()
            dismissSettings?()

          } // Button
          .buttonStyle(.borderedProminent)

          Spacer()

        } // HStack
        .padding()

      } // VStack
      .navigationTitle("Change Location")
      .navigationBarTitleDisplayMode(.inline)

    } // NavigationView
    .onAppear
    {

              // Initialize with manual location if set, otherwise use current GPS location

      if let manualLoc = viewModel.manualLocation, viewModel.isUsingManualLocation
      {
        selectedCoordinate   = manualLoc.coordinate
        region.center        = manualLoc.coordinate
        selectedLocationName = viewModel.manualLocationName

                // Populate search text with location name

        if let locationName = viewModel.manualLocationName
        {
          searchText = locationName

        } // if

      } // if
      else if let currentLocation = viewModel.locationManager.location
      {
        selectedCoordinate   = currentLocation.coordinate
        region.center        = currentLocation.coordinate
        selectedLocationName = nil

                // Get current location name and populate search text

        reverseGeocodeForDisplay(currentLocation.coordinate)

      } // else if

    } // onAppear
    .fullScreenCover(isPresented: $showingFullScreenMap)
    {
      FullScreenMapView(
        region             : $region,
        selectedCoordinate : $selectedCoordinate,
        mapType            : $mapType,
        onLocationSelected :
        {
          coordinate in

          reverseGeocode(coordinate)
          showingFullScreenMap = false

        } // onLocationSelected
      )

    } // fullScreenCover

  } // body

  // MARK: - Helper Functions

  // ------------------------------

  private func selectSearchResult(
    _ result: MKLocalSearchCompletion
  )
  {
    let searchRequest = MKLocalSearch.Request(completion: result)
    let search        = MKLocalSearch(request: searchRequest)

    search.start
    {
      response, error in

      guard let response = response,
            let item = response.mapItems.first
      else
      {
        return

      } // guard

      let coordinate          = item.location.coordinate
      selectedCoordinate      = coordinate
      region.center           = coordinate
      searchText              = result.title
      selectedLocationName    = result.title
      searchCompleter.results = []

              // Immediately set the manual location

      viewModel.setManualLocation(
        item.location,
        name: result.title
      )

    } // search.start

  } // selectSearchResult

  // ------------------------------

  private func selectRecentLocation(
    _ recent: RecentLocation
  )
  {
    let coordinate = recent.coordinate

    selectedCoordinate   = coordinate
    region.center        = coordinate
    searchText           = recent.name
    selectedLocationName = recent.name

    viewModel.setManualLocation(
      CLLocation(
        latitude  : coordinate.latitude,
        longitude : coordinate.longitude
      ),
      name: recent.name
    )

  } // selectRecentLocation

  // ------------------------------

  private func useCurrentLocation()
  {
    if let currentLocation = viewModel.locationManager.location
    {
      selectedCoordinate   = currentLocation.coordinate
      region.center        = currentLocation.coordinate
      searchText           = ""
      selectedLocationName = nil
      viewModel.clearManualLocation()

              // Close the Change Location view, then close the Settings view

      dismiss()
      dismissSettings?()

    } // if

  } // useCurrentLocation

  // ------------------------------

  private func reverseGeocode(
    _ coordinate: CLLocationCoordinate2D
  )
  {
    let location = CLLocation(
      latitude  : coordinate.latitude,
      longitude : coordinate.longitude
    )

    Task
    {
      guard let request = MKReverseGeocodingRequest(location: location)
      else
      {
        selectedLocationName = "Selected Location"
        viewModel.setManualLocation(
          location,
          name: "Selected Location"
        )
        return

      } // guard

              // A lookup failure is treated the same as no results

      let items = try? await request.mapItems

      var locationName: String

      if let mapItem = items?.first
      {

                // Build location name from map item

        var nameParts: [String] = []

        if let name = mapItem.name
        {
          nameParts.append(name)

        } // if

                // Use cityWithContext for locality and administrative area

        if let cityContext = mapItem.addressRepresentations?.cityWithContext
        {
          nameParts.append(cityContext)

        } // if

        locationName = nameParts.joined(separator: ", ")

      } // if
      else
      {
        locationName = "Selected Location"

      } // else

      selectedLocationName = locationName

              // Immediately set the manual location

      viewModel.setManualLocation(
        location,
        name: locationName
      )

    } // Task

  } // reverseGeocode

  // ------------------------------

  private func reverseGeocodeForDisplay(
    _ coordinate: CLLocationCoordinate2D
  )
  {
    let location = CLLocation(
      latitude  : coordinate.latitude,
      longitude : coordinate.longitude
    )

    Task
    {
      guard let request = MKReverseGeocodingRequest(location: location)
      else
      {
        searchText = "Current Location"
        return

      } // guard

              // A lookup failure is treated the same as no results

      let items = try? await request.mapItems

      var locationName: String

      if let mapItem = items?.first
      {

                // Use cityWithContext for locality and administrative area

        if let cityContext = mapItem.addressRepresentations?.cityWithContext
        {
          locationName = cityContext

        } // if
        else if let name = mapItem.name
        {
          locationName = name

        } // else if
        else
        {
          locationName = "Current Location"

        } // else

      } // if
      else
      {
        locationName = "Current Location"

      } // else

              // Only update search text for display, don't set manual location

      searchText = locationName

    } // Task

  } // reverseGeocodeForDisplay

} // struct ChangeLocationView

// MARK: - Supporting Types

// ----------------------------------------

struct MapPin: Identifiable
{
  let id         = UUID()
  let coordinate : CLLocationCoordinate2D

} // struct MapPin

// ----------------------------------------

@Observable
class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate
{
  var results : [MKLocalSearchCompletion] = []

  private let completer = MKLocalSearchCompleter()

  var searchQuery: String = ""
  {
    didSet
    {
      completer.queryFragment = searchQuery

    } // didSet

  } // var searchQuery

  // ------------------------------

  override init()
  {
    super.init()
    completer.delegate = self

  } // init

  // ------------------------------

  func completerDidUpdateResults(
    _ completer: MKLocalSearchCompleter
  )
  {
    results = completer.results

  } // completerDidUpdateResults

  // ------------------------------

  func completer(
    _ completer            : MKLocalSearchCompleter,
    didFailWithError error : Error
  )
  {
    print("Location search error: \(error.localizedDescription)")

  } // completer didFailWithError

} // class LocationSearchCompleter

// MARK: - Tappable Map View

// ----------------------------------------

struct TappableMapView: UIViewRepresentable
{
  @Binding var region             : MKCoordinateRegion
  @Binding var selectedCoordinate : CLLocationCoordinate2D?
  @Binding var mapType            : MKMapType
  var onCoordinateSelected        : ((CLLocationCoordinate2D) -> Void)?

  // ------------------------------

  func makeUIView(
    context: Context
  ) -> MKMapView
  {
    let mapView = MKMapView()
    mapView.delegate = context.coordinator
    mapView.setRegion(
      region,
      animated: false
    )
    mapView.mapType         = mapType
    mapView.isScrollEnabled = false
    mapView.isZoomEnabled   = false
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled  = false

    return mapView

  } // makeUIView

  // ------------------------------

  func updateUIView(
    _ mapView : MKMapView,
    context   : Context
  )
  {
    mapView.setRegion(
      region,
      animated: true
    )
    mapView.mapType = mapType

            // Remove existing annotations

    mapView.removeAnnotations(mapView.annotations)

            // Add pin if coordinate is selected

    if let coordinate = selectedCoordinate
    {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coordinate
      mapView.addAnnotation(annotation)

    } // if

  } // updateUIView

  // ------------------------------

  func makeCoordinator() -> Coordinator
  {
    Coordinator(self)

  } // makeCoordinator

  // ----------------------------------------

  class Coordinator: NSObject, MKMapViewDelegate
  {
    var parent: TappableMapView

    // ------------------------------

    init(
      _ parent: TappableMapView
    )
    {
      self.parent = parent

    } // init

    // Don't update region binding for small map - it's static

  } // class Coordinator

} // struct TappableMapView

// MARK: - Full Screen Map View

// ----------------------------------------

struct FullScreenMapView: View
{
  @Environment(\.dismiss) var dismiss
  @Binding var region             : MKCoordinateRegion
  @Binding var selectedCoordinate : CLLocationCoordinate2D?
  @Binding var mapType            : MKMapType
  var onLocationSelected          : ((CLLocationCoordinate2D) -> Void)?

  // ------------------------------

  var body: some View
  {
    ZStack
    {

              // Full screen map

      FullScreenTappableMapView(
        region               : $region,
        selectedCoordinate   : $selectedCoordinate,
        mapType              : $mapType,
        onCoordinateSelected :
        {
          coordinate in

          onLocationSelected?(coordinate)

        } // onCoordinateSelected
      )
      .edgesIgnoringSafeArea(.all)

      VStack
      {
        HStack
        {
          Spacer()

          VStack(spacing: 12)
          {

                    // Close button

            Button(
              action:
              {
                dismiss()

              } // action
            )
            {
              Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))

            } // Button

                    // Map type toggle button

            Button(
              action:
              {
                mapType = mapType == .standard ? .hybrid : .standard

              } // action
            )
            {
              Image(systemName: mapType == .standard ? "map" : "map.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)

            } // Button

          } // VStack
          .padding()

        } // HStack

        Spacer()

      } // VStack

    } // ZStack

  } // body

} // struct FullScreenMapView

// MARK: - Full Screen Tappable Map View

// ----------------------------------------

struct FullScreenTappableMapView: UIViewRepresentable
{
  @Binding var region             : MKCoordinateRegion
  @Binding var selectedCoordinate : CLLocationCoordinate2D?
  @Binding var mapType            : MKMapType
  var onCoordinateSelected        : ((CLLocationCoordinate2D) -> Void)?

  // ------------------------------

  func makeUIView(
    context: Context
  ) -> MKMapView
  {
    let mapView = MKMapView()
    mapView.delegate = context.coordinator
    mapView.setRegion(
      region,
      animated: false
    )
    mapView.mapType = mapType

    let tapGesture = UITapGestureRecognizer(
      target : context.coordinator,
      action : #selector(Coordinator.handleTap(_:))
    )
    mapView.addGestureRecognizer(tapGesture)

    return mapView

  } // makeUIView

  // ------------------------------

  func updateUIView(
    _ mapView : MKMapView,
    context   : Context
  )
  {
    mapView.setRegion(
      region,
      animated: true
    )
    mapView.mapType = mapType

            // Remove existing annotations

    mapView.removeAnnotations(mapView.annotations)

            // Add pin if coordinate is selected

    if let coordinate = selectedCoordinate
    {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coordinate
      mapView.addAnnotation(annotation)

    } // if

  } // updateUIView

  // ------------------------------

  func makeCoordinator() -> Coordinator
  {
    Coordinator(self)

  } // makeCoordinator

  // ----------------------------------------

  class Coordinator: NSObject, MKMapViewDelegate
  {
    var parent: FullScreenTappableMapView

    // ------------------------------

    init(
      _ parent: FullScreenTappableMapView
    )
    {
      self.parent = parent

    } // init

    // ------------------------------

    @objc func handleTap(
      _ gesture: UITapGestureRecognizer
    )
    {
      let mapView    = gesture.view as! MKMapView
      let location   = gesture.location(in: mapView)
      let coordinate = mapView.convert(
        location,
        toCoordinateFrom: mapView
      )

      parent.selectedCoordinate = coordinate
      parent.onCoordinateSelected?(coordinate)

    } // handleTap

    // ------------------------------

    func mapView(
      _ mapView                   : MKMapView,
      regionDidChangeAnimated animated : Bool
    )
    {
      parent.region = mapView.region

    } // mapView regionDidChangeAnimated

  } // class Coordinator

} // struct FullScreenTappableMapView
