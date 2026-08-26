//
//  ChangeLocationView.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/13/26.
//

import SwiftUI
import MapKit
import Observation

struct ChangeLocationView: View
{
  @Environment(\.dismiss) var dismiss
  var viewModel: BirdReporterViewModel
  var dismissSettings: (() -> Void)?
  
  @State private var searchText = ""
  @State private var searchResults: [MKLocalSearchCompletion] = []
  @State private var selectedCoordinate: CLLocationCoordinate2D?
  @State private var selectedLocationName: String?
  @State private var region = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
  )
  @State private var showingFullScreenMap = false
  @FocusState private var isSearchFieldFocused: Bool
  @State private var mapType: MKMapType = .standard
  
  @State private var searchCompleter = LocationSearchCompleter()
  
  var body: some View
  {
    NavigationView
    {
      VStack(spacing: 0)
      {
        // Search bar with icons
        HStack
        {
          Button(action: {
            if !searchText.isEmpty
            {
              // Perform search
              searchCompleter.searchQuery = searchText
            }
          })
          {
            Image(systemName: "magnifyingglass")
              .foregroundColor(.blue)
          }
          .buttonStyle(.borderless)
          
          Button(action: {
            useCurrentLocation()
          })
          {
            Image(systemName: "location.north.fill")
              .foregroundColor(.blue)
          }
          .buttonStyle(.borderless)
          
          HStack
          {
            TextField("Search location", text: $searchText)
              .textFieldStyle(.plain)
              .focused($isSearchFieldFocused)
              .onChange(of: searchText)
              { oldValue, newValue in
                searchCompleter.searchQuery = newValue
              }
            
            if !searchText.isEmpty
            {
              Button(action: {
                searchText = ""
                searchCompleter.results = []
                isSearchFieldFocused = true
              })
              {
                Image(systemName: "xmark.circle.fill")
                  .foregroundColor(.gray)
              }
              .buttonStyle(.borderless)
            }
          }
          .padding(8)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(.systemGray6))
          )
          
        } // HStack
        .padding()
        
        // Search results
        if !searchCompleter.results.isEmpty && !searchText.isEmpty
        {
          List(searchCompleter.results, id: \.self)
          { result in
            Button(action: {
              selectSearchResult(result)
            })
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
            region: $region,
            selectedCoordinate: $selectedCoordinate,
            mapType: $mapType,
            onCoordinateSelected: { coordinate in
              reverseGeocode(coordinate)
            }
          )
          .onTapGesture
          {
            showingFullScreenMap = true
          }
          
          // Map type toggle button
          Button(action: {
            mapType = mapType == .standard ? .hybrid : .standard
          })
          {
            Image(systemName: mapType == .standard ? "map" : "map.fill")
              .padding(8)
              .background(Color.white.opacity(0.9))
              .cornerRadius(8)
              .shadow(radius: 2)
          }
          .padding(8)
        }
        
        Spacer()
        
        // Done button
        HStack
        {
          Spacer()
          
          Button("Done")
          {
            dismiss()
            dismissSettings?()
          }
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
        selectedCoordinate = manualLoc.coordinate
        region.center = manualLoc.coordinate
        selectedLocationName = viewModel.manualLocationName
        // Populate search text with location name
        if let locationName = viewModel.manualLocationName
        {
          searchText = locationName
        }
      }
      else if let currentLocation = viewModel.locationManager.location
      {
        selectedCoordinate = currentLocation.coordinate
        region.center = currentLocation.coordinate
        selectedLocationName = nil
        // Get current location name and populate search text
        reverseGeocodeForDisplay(currentLocation.coordinate)
      }
    }
    .fullScreenCover(isPresented: $showingFullScreenMap)
    {
      FullScreenMapView(
        region: $region,
        selectedCoordinate: $selectedCoordinate,
        mapType: $mapType,
        onLocationSelected: { coordinate in
          reverseGeocode(coordinate)
          showingFullScreenMap = false
        }
      )
    }
    
  } // body
  
  // MARK: - Helper Functions
  
  private func selectSearchResult(_ result: MKLocalSearchCompletion)
  {
    let searchRequest = MKLocalSearch.Request(completion: result)
    let search = MKLocalSearch(request: searchRequest)
    
    search.start
    { response, error in
      guard let response = response,
            let item = response.mapItems.first
      else
      {
        return
      }
      
      let coordinate = item.location.coordinate
      selectedCoordinate = coordinate
      region.center = coordinate
      searchText = result.title
      selectedLocationName = result.title
      searchCompleter.results = []
      
      // Immediately set the manual location
      viewModel.setManualLocation(item.location, name: result.title)
    }
  }
  
  private func useCurrentLocation()
  {
    if let currentLocation = viewModel.locationManager.location
    {
      selectedCoordinate = currentLocation.coordinate
      region.center = currentLocation.coordinate
      searchText = ""
      selectedLocationName = nil
      viewModel.clearManualLocation()
      dismiss()  // Close the Change Location view
      dismissSettings?()  // Close the Settings view
    }
  }
  
  private func reverseGeocode(_ coordinate: CLLocationCoordinate2D)
  {
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    
    Task
    {
      guard let request = MKReverseGeocodingRequest(location: location) else
      {
        selectedLocationName = "Selected Location"
        viewModel.setManualLocation(location, name: "Selected Location")
        return
      }
      
      request.getMapItems
      { items, error in
        var locationName: String
        
        if let mapItem = items?.first
        {
          // Build location name from map item
          var nameParts: [String] = []
          
          if let name = mapItem.name
          {
            nameParts.append(name)
          }
          
          // Use cityWithContext for locality and administrative area
          if let cityContext = mapItem.addressRepresentations?.cityWithContext
          {
            nameParts.append(cityContext)
          }
          
          locationName = nameParts.joined(separator: ", ")
        }
        else
        {
          locationName = "Selected Location"
        }
        
        selectedLocationName = locationName
        
        // Immediately set the manual location
        viewModel.setManualLocation(location, name: locationName)
      }
    }
  }
  
  private func reverseGeocodeForDisplay(_ coordinate: CLLocationCoordinate2D)
  {
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    
    Task
    {
      guard let request = MKReverseGeocodingRequest(location: location) else
      {
        searchText = "Current Location"
        return
      }
      
      request.getMapItems
      { items, error in
        var locationName: String
        
        if let mapItem = items?.first
        {
          // Use cityWithContext for locality and administrative area
          if let cityContext = mapItem.addressRepresentations?.cityWithContext
          {
            locationName = cityContext
          }
          else if let name = mapItem.name
          {
            locationName = name
          }
          else
          {
            locationName = "Current Location"
          }
        }
        else
        {
          locationName = "Current Location"
        }
        
        // Only update search text for display, don't set manual location
        searchText = locationName
      }
    }
  }
  
} // ChangeLocationView

// MARK: - Supporting Types

struct MapPin: Identifiable
{
  let id = UUID()
  let coordinate: CLLocationCoordinate2D
}

@Observable
class LocationSearchCompleter: NSObject, MKLocalSearchCompleterDelegate
{
  var results: [MKLocalSearchCompletion] = []
  
  private let completer = MKLocalSearchCompleter()
  
  var searchQuery: String = ""
  {
    didSet
    {
      completer.queryFragment = searchQuery
    }
  }
  
  override init()
  {
    super.init()
    completer.delegate = self
  }
  
  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter)
  {
    results = completer.results
  }
  
  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error)
  {
    print("Location search error: \(error.localizedDescription)")
  }
}

// MARK: - Tappable Map View

struct TappableMapView: UIViewRepresentable
{
  @Binding var region: MKCoordinateRegion
  @Binding var selectedCoordinate: CLLocationCoordinate2D?
  @Binding var mapType: MKMapType
  var onCoordinateSelected: ((CLLocationCoordinate2D) -> Void)?
  
  func makeUIView(context: Context) -> MKMapView
  {
    let mapView = MKMapView()
    mapView.delegate = context.coordinator
    mapView.setRegion(region, animated: false)
    mapView.mapType = mapType
    mapView.isScrollEnabled = false
    mapView.isZoomEnabled = false
    mapView.isRotateEnabled = false
    mapView.isPitchEnabled = false
    
    return mapView
  }
  
  func updateUIView(_ mapView: MKMapView, context: Context)
  {
    mapView.setRegion(region, animated: true)
    mapView.mapType = mapType
    
    // Remove existing annotations
    mapView.removeAnnotations(mapView.annotations)
    
    // Add pin if coordinate is selected
    if let coordinate = selectedCoordinate
    {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coordinate
      mapView.addAnnotation(annotation)
    }
  }
  
  func makeCoordinator() -> Coordinator
  {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, MKMapViewDelegate
  {
    var parent: TappableMapView
    
    init(_ parent: TappableMapView)
    {
      self.parent = parent
    }
    
    // Don't update region binding for small map - it's static
  }
}

// MARK: - Full Screen Map View

struct FullScreenMapView: View
{
  @Environment(\.dismiss) var dismiss
  @Binding var region: MKCoordinateRegion
  @Binding var selectedCoordinate: CLLocationCoordinate2D?
  @Binding var mapType: MKMapType
  var onLocationSelected: ((CLLocationCoordinate2D) -> Void)?
  
  var body: some View
  {
    ZStack
    {
      // Full screen map
      FullScreenTappableMapView(
        region: $region,
        selectedCoordinate: $selectedCoordinate,
        mapType: $mapType,
        onCoordinateSelected: { coordinate in
          onLocationSelected?(coordinate)
        }
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
            Button(action: {
              dismiss()
            })
            {
              Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.5)))
            }
            
            // Map type toggle button
            Button(action: {
              mapType = mapType == .standard ? .hybrid : .standard
            })
            {
              Image(systemName: mapType == .standard ? "map" : "map.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
            }
          }
          .padding()
        }
        
        Spacer()
      }
      
    } // ZStack
    
  } // body
}

// MARK: - Full Screen Tappable Map View

struct FullScreenTappableMapView: UIViewRepresentable
{
  @Binding var region: MKCoordinateRegion
  @Binding var selectedCoordinate: CLLocationCoordinate2D?
  @Binding var mapType: MKMapType
  var onCoordinateSelected: ((CLLocationCoordinate2D) -> Void)?
  
  func makeUIView(context: Context) -> MKMapView
  {
    let mapView = MKMapView()
    mapView.delegate = context.coordinator
    mapView.setRegion(region, animated: false)
    mapView.mapType = mapType
    
    let tapGesture = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:))
    )
    mapView.addGestureRecognizer(tapGesture)
    
    return mapView
  }
  
  func updateUIView(_ mapView: MKMapView, context: Context)
  {
    mapView.setRegion(region, animated: true)
    mapView.mapType = mapType
    
    // Remove existing annotations
    mapView.removeAnnotations(mapView.annotations)
    
    // Add pin if coordinate is selected
    if let coordinate = selectedCoordinate
    {
      let annotation = MKPointAnnotation()
      annotation.coordinate = coordinate
      mapView.addAnnotation(annotation)
    }
  }
  
  func makeCoordinator() -> Coordinator
  {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, MKMapViewDelegate
  {
    var parent: FullScreenTappableMapView
    
    init(_ parent: FullScreenTappableMapView)
    {
      self.parent = parent
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer)
    {
      let mapView = gesture.view as! MKMapView
      let location = gesture.location(in: mapView)
      let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
      
      parent.selectedCoordinate = coordinate
      parent.onCoordinateSelected?(coordinate)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool)
    {
      parent.region = mapView.region
    }
  }
}
