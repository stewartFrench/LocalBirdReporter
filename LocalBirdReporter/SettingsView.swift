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

  // ------------------------------

  var body: some View
  {
    NavigationStack
    {
      Form
      {
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

        } // Section Auto Check

        Section(
          header: Text("Display Settings")
        )
        {
          Stepper(
            "Display: \(viewModel.maxBirdsToDisplay) birds",
            value : $viewModel.maxBirdsToDisplay,
            in    : 1...50
          )

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

          Stepper(
            viewModel.distanceUnit == .kilometers
              ? "Mark all birds New after moving: \(viewModel.resetDistanceKm) km"
              : "Mark all birds New after moving: \(Int(Double(viewModel.resetDistanceKm) / 1.60934)) miles",
            value : $viewModel.resetDistanceKm,
            in    : 1...50
          )

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

        } // Section Display Settings

        Section(
          header: Text("Speech Settings")
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

          Stepper(
            "Speak: \(viewModel.maxBirdsToSpeak) birds",
            value : $viewModel.maxBirdsToSpeak,
            in    : 1...30
          )

        } // Section Speech Settings

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

    } // NavigationStack

  } // body

} // struct SettingsView
