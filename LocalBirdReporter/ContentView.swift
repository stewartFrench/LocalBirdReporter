//
//  ContentView.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import SwiftUI

// ----------------------------------------

struct ContentView: View
{
  @State private var viewModel         = BirdReporterViewModel()
  @State private var showingSettings   = false
  @State private var showingAbouteBird = false

  // ------------------------------

  var body: some View
  {
    VStack(
      spacing: 0
    )
    {

              // Centered Title at the very top with settings button

      VStack(
        spacing: 4
      )
      {
        HStack
        {
          Spacer()
          Button(
            action:
            {
              showingAbouteBird = true
            } // action
          )
          {
            Text("Local Bird Reporter")
              .font(.largeTitle)
              .fontWeight(.bold)
              .foregroundColor(.primary)
          } // Button
          Spacer()
        } // HStack

        HStack
        {
          Spacer()
          Button(
            action:
            {
              showingAbouteBird = true
            } // action
          )
          {
            Text("Powered by eBird")
              .font(.subheadline)
              .foregroundColor(.blue)
          } // Button
          Spacer()
        } // HStack
        .overlay(
          alignment: .trailing
        )
        {
          Button(
            action:
            {
              showingSettings = true
            } // action
          )
          {
            Image(
              systemName: "gear"
            )
            .font(.title2)
            .foregroundColor(.blue)
          } // Button
          .padding(
            .trailing,
            16
          )
        } // overlay
        .padding(
          .top,
          2
        )

                // Location display with button to reset to current GPS location

        HStack(
          spacing: 6
        )
        {
          if viewModel.isUsingManualLocation, let locationName = viewModel.manualLocationName
          {
            Text(locationName)
              .font(.caption)
              .foregroundColor(.orange)
              .fontWeight(.semibold)
          } // if
          else
          {
            Text("Using current GPS location")
              .font(.caption)
              .foregroundColor(.secondary)
          } // else

          Button(
            action:
            {
              viewModel.clearManualLocation()
            } // action
          )
          {
            Image(systemName: "location.fill")
              .font(.caption)
              .foregroundColor(.blue)
          } // Button
          .disabled(!viewModel.isUsingManualLocation)

        } // HStack
        .padding(
          .top,
          4
        )

        Text("Sorted by: \(viewModel.sortMode.rawValue)")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(
            .top,
            6
          )

        Text(
          viewModel.distanceUnit == .kilometers
            ? "Search radius: \(viewModel.searchRadiusKm) km   " +
              "From last: \(viewModel.daysBack) days"
            : "Search radius: \(Int(Double(viewModel.searchRadiusKm) / 1.60934)) miles   " +
              "From last: \(viewModel.daysBack) days"
        )
          .font(.caption)
          .foregroundColor(.secondary)
      } // VStack
      .padding(
        .top,
        8
      )
      .padding(
        .bottom,
        12
      )
      .background(Color(UIColor.systemBackground))

              // Fixed-height status area outside NavigationStack

      VStack
      {
        if viewModel.isLoading
        {
          ProgressView("Fetching birds...")
        } // if
        else if let error = viewModel.errorMessage
        {
          Text(error)
            .foregroundColor(.red)
            .font(.caption)
            .multilineTextAlignment(.center)
        } // else if
        else if let message = viewModel.distanceMessage
        {
          Text(message)
            .foregroundColor(.primary)
            .font(.caption)
            .multilineTextAlignment(.center)
        } // else if
        else
        {
          Text(" ")
            .font(.caption)
        } // else
      } // VStack
      .frame(
        height: 44
      )
      .frame(
        maxWidth: .infinity
      )
      .padding(.horizontal)
      .padding(
        .vertical,
        4
      )
      .background(Color(UIColor.systemBackground))

              // Main content area

      if viewModel.birds.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil
      {
        VStack(
          spacing: 10
        )
        {
          Image(
            systemName: "bird"
          )
          .font(.system(size: 60))
          .foregroundColor(.blue)
          Text("No birds found yet")
            .font(.headline)
          Text("Tap the button below to find local birds")
            .font(.caption)
            .foregroundColor(.secondary)
        } // VStack
        .frame(
          maxWidth : .infinity,
          maxHeight: .infinity
        )
      } // if
      else if !viewModel.birds.isEmpty
      {
        ScrollViewReader
        {
          proxy in

          List(viewModel.birds)
          {
            bird in

            VStack(
              alignment : .leading,
              spacing   : 4
            )
            {
              Button(
                action:
                {
                  openBirdInfo(for: bird)
                } // action
              )
              {
                HStack
                {
                  if bird.isNew
                  {
                    NewBadge()
                  } // if
                  Text(bird.comName)
                    .font(.headline)
                    .fontWeight(bird.isNew ? .bold : .regular)
                    .foregroundColor(.primary)
                  Spacer()
                  if let count = bird.howMany
                  {
                    Text("\(count)")
                      .font(.headline)
                      .foregroundColor(.blue)
                  } // if
                } // HStack
              } // Button
              .buttonStyle(.plain)

              HStack
              {
                Button(
                  action:
                  {
                    openBirdLocation(for: bird)
                  } // action
                )
                {
                  Text(bird.locName)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .underline()
                } // Button
                .buttonStyle(.plain)

                Spacer()
              } // HStack

              Text(formatDate(bird.obsDt))
                .font(.caption2)
                .foregroundColor(.secondary)
            } // VStack
            .padding(
              .vertical,
              4
            )
            .listRowBackground(bird.isNew ? Color.yellow.opacity(0.1) : Color.clear)
            .id(bird.id)
          } // List
          .listStyle(.plain)
          .onChange(of: viewModel.shouldScrollToTop)
          {
            oldValue, newValue in

            if newValue, let firstBird = viewModel.birds.first
            {
              withAnimation
              {
                proxy.scrollTo(
                  firstBird.id,
                  anchor: .top
                )
              } // withAnimation
              viewModel.shouldScrollToTop = false
            } // if
          } // onChange
        } // ScrollViewReader
      } // else if
      else
      {
        Spacer()
      } // else

              // Fixed buttons at bottom

      VStack(
        spacing: 12
      )
      {

                // Stop Speaking button

        Button(
          action:
          {
            viewModel.stopSpeaking()
          } // action
        )
        {
          HStack
          {
            Image(
              systemName: "stop.circle"
            )
            Text("Stop Speaking")
          } // HStack
          .frame(
            maxWidth: .infinity
          )
          .padding()
          .background(viewModel.isSpeaking ? Color.red : Color.gray.opacity(0.3))
          .foregroundColor(.white)
          .cornerRadius(10)
        } // Button
        .disabled(!viewModel.isSpeaking)

                // Fetch Local Birds button

        Button(
          action:
          {
            viewModel.fetchBirds()
          } // action
        )
        {
          HStack
          {
            Image(
              systemName: "arrow.clockwise"
            )
            Text("Fetch Local Birds")
          } // HStack
          .frame(
            maxWidth: .infinity
          )
          .padding()
          .background(
            (viewModel.isLoading || viewModel.isSpeaking)
              ? Color.gray.opacity(0.3)
              : Color.blue
          )
          .foregroundColor(
            (viewModel.isLoading || viewModel.isSpeaking)
              ? Color.gray
              : Color.white
          )
          .cornerRadius(10)
        } // Button
        .disabled(viewModel.isLoading || viewModel.isSpeaking)
      } // VStack
      .padding()
      .background(Color(UIColor.systemBackground))
      .onAppear
      {
        viewModel.requestLocation()
      } // onAppear
      .sheet(
        isPresented: $showingSettings
      )
      {
        SettingsView(
          viewModel: $viewModel
        )
      } // sheet
      .sheet(
        isPresented: $showingAbouteBird
      )
      {
        AbouteBirdView()
      } // sheet
    } // VStack
  } // body

  // ------------------------------

  private func openBirdInfo(
    for bird: BirdObservation
  )
  {

            // Create URL for eBird species page using the species code

    let urlString = "https://ebird.org/species/\(bird.speciesCode)"

    print("Opening eBird page for: \(bird.comName) - \(urlString)")

    if let url = URL(string: urlString)
    {
      UIApplication.shared.open(url)
    } // if
  } // openBirdInfo

  // ------------------------------

  private func openBirdLocation(
    for bird: BirdObservation
  )
  {

            // Create Apple Maps URL with the bird's coordinates

    let urlString = "http://maps.apple.com/?q=\(bird.lat),\(bird.lng)" +
                    "&ll=\(bird.lat),\(bird.lng)"

    print("Opening map for: \(bird.comName) at \(bird.locName) - \(urlString)")

    if let url = URL(string: urlString)
    {
      UIApplication.shared.open(url)
    } // if
  } // openBirdLocation

  // ------------------------------

  private func formatDate(
    _ dateString: String
  ) -> String
  {

            // eBird date format is "2026-08-06 14:30" (year-month-day hour:minute)

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    if let date = formatter.date(from: dateString)
    {
      let displayFormatter = DateFormatter()
      displayFormatter.dateStyle = .short
      displayFormatter.timeStyle = .short
      return displayFormatter.string(from: date)
    } // if

    return dateString
  } // formatDate
} // ContentView

// ----------------------------------------

struct NewBadge: View
{
  @State private var isAnimating = false

  // ------------------------------

  var body: some View
  {
    Text("🆕")
      .font(.caption)
      .scaleEffect(isAnimating ? 1.2 : 1.0)
      .animation(
        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
        value: isAnimating
      )
      .onAppear
      {
        isAnimating = true
      } // onAppear
  } // body
} // struct NewBadge

#Preview
{
  ContentView()
} // Preview

