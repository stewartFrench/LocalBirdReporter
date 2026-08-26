//
//  SettingsView.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import SwiftUI
import AVFoundation

// ----------------------------------------

struct SettingsView: View
{
  @Binding var viewModel                : BirdReporterViewModel
  @Environment(\.dismiss) var dismiss
  @State private var availableVoices    : [AVSpeechSynthesisVoice] = []
  @State private var showingChangeLocation = false

  // ------------------------------

  var body: some View
  {
    NavigationStack
    {
      Form
      {
        Section(
          header: Text("Search & Display")
        )
        {
          Picker(
            "Sort by",
            selection: $viewModel.sortMode
          )
          {
            ForEach(
              BirdSortMode.allCases,
              id: \.self
            )
            { mode in
              Text(mode.rawValue).tag(mode)

            } // ForEach

          } // Picker

          Stepper(
            viewModel.distanceUnit == .kilometers
              ? "Search radius: \(viewModel.searchRadiusKm) km"
              : "Search radius: \(Int(Double(viewModel.searchRadiusKm) / 1.60934)) miles",
            value : $viewModel.searchRadiusKm,
            in    : 1...50
          )

          Stepper(
            "Show birds from last: \(viewModel.daysBack) days",
            value : $viewModel.daysBack,
            in    : 1...30
          )

          Stepper(
            "Display: \(viewModel.maxBirdsToDisplay) birds",
            value : $viewModel.maxBirdsToDisplay,
            in    : 1...50
          )

          Stepper(
            viewModel.distanceUnit == .kilometers
              ? "Mark all birds New after moving: \(viewModel.resetDistanceKm) km"
              : "Mark all birds New after moving: \(Int(Double(viewModel.resetDistanceKm) / 1.60934)) miles",
            value : $viewModel.resetDistanceKm,
            in    : 1...50
          )

        } // Section Search & Display

        Section(
          header: Text("Location")
        )
        {
          Button("Change Location")
          {
            showingChangeLocation = true
          }
          
          if viewModel.isUsingManualLocation, let locationName = viewModel.manualLocationName
          {
            Text("Currently: \(locationName)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          else if viewModel.isUsingManualLocation
          {
            Text("Using manual location")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          else
          {
            Text("Using current GPS location")
              .font(.caption)
              .foregroundColor(.secondary)
          }

        } // Section Location

        Section(
          header: Text("Auto Check")
        )
        {
          Stepper(
            "Check every \(viewModel.checkIntervalMinutes) minutes",
            value : $viewModel.checkIntervalMinutes,
            in    : 1...120
          )

          Toggle(
            "Enable Auto Check",
            isOn: $viewModel.isAutoCheckEnabled
          )
          .onChange(
            of: viewModel.isAutoCheckEnabled
          )
          { oldValue, newValue in
            if newValue
            {
              viewModel.startAutoCheck()

            } // if
            else
            {
              viewModel.stopAutoCheck()

            } // else

          } // onChange

          Toggle(
            "Announce 'No new birds'",
            isOn: $viewModel.announceNoNewBirds
          )

        } // Section Auto Check

        Section(
          header: Text("Speech")
        )
        {
          Stepper(
            viewModel.maxBirdsToSpeak == 0 
              ? "Speaking: Off" 
              : "Speak: \(viewModel.maxBirdsToSpeak) birds",
            value : $viewModel.maxBirdsToSpeak,
            in    : 0...30
          )

        } // Section Speech

        Section(
          header: Text("Voice")
        )
        {
          Picker(
            "Voice",
            selection: Binding(
              get: { viewModel.selectedVoiceIdentifier ?? "" },
              set: { viewModel.selectedVoiceIdentifier = $0.isEmpty ? nil : $0 }
            )
          )
          {
            ForEach(
              availableVoices,
              id: \.identifier
            )
            { voice in
              Text(voice.name).tag(voice.identifier)

            } // ForEach

          } // Picker

        } // Section Voice

        Section(
          header: Text("Distance Units")
        )
        {
          Picker(
            "Distance units",
            selection: $viewModel.distanceUnit
          )
          {
            ForEach(
              DistanceUnit.allCases,
              id: \.self
            )
            { unit in
              Text(unit.rawValue).tag(unit)

            } // ForEach

          } // Picker

        } // Section Distance Units

        Section(
          header: Text("eBird API")
        )
        {
          SecureField(
            "API Key",
            text  : $viewModel.apiKey
          )
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)

          Link(
            "Get a free API key",
            destination: URL(string: "https://ebird.org/api/keygen")!
          )
          .font(.caption)

        } // Section eBird API

      } // Form
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear
      {
        availableVoices = SpeechService.getAvailableVoices()

      } // onAppear
      .toolbar
      {
        ToolbarItem(
          placement: .confirmationAction
        )
        {
          Button("Done")
          {
            dismiss()

          } // Button

        } // ToolbarItem

      } // toolbar
      .sheet(isPresented: $showingChangeLocation)
      {
        ChangeLocationView(viewModel: viewModel, dismissSettings: {
          dismiss()
        })
      }

    } // NavigationStack

  } // body

} // struct SettingsView
