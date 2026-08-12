//
//  AbouteBirdView.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import SwiftUI

// ----------------------------------------

struct AbouteBirdView: View
{
  @Environment(\.dismiss) var dismiss
  
  // ------------------------------
  
  var body: some View
  {
    NavigationStack
    {
      ScrollView
      {
        VStack(
          alignment : .leading,
          spacing   : 20
        )
        {
          VStack(
            alignment : .center,
            spacing   : 8
          )
          {
            Image(systemName: "bird.fill")
              .font(.system(size: 60))
              .foregroundColor(.blue)
            
            Text("About eBird")
              .font(.title)
              .fontWeight(.bold)
            
          } // VStack
          .frame(maxWidth: .infinity)
          .padding(.bottom, 10)
          
          Text("Tribute to eBird")
            .font(.headline)
          
          Text("This app is powered by eBird, a real-time, online database of bird observations providing scientists, researchers, and amateur naturalists with real-time data about bird distribution and abundance.")
            .font(.body)
          
          Text("What is eBird?")
            .font(.headline)
            .padding(.top, 10)
          
          Text("eBird is a joint project of the Cornell Lab of Ornithology and the National Audubon Society. Since its launch in 2002, eBird has become the world's largest biodiversity-related citizen science project, with more than 100 million bird sightings contributed each year by eBirders around the world.")
            .font(.body)
          
          Text("How it Works")
            .font(.headline)
            .padding(.top, 10)
          
          Text("Birdwatchers enter when, where, and how they went birding, and then fill out a checklist of all the birds seen and heard during the outing. This data is used by researchers, conservation biologists, and land managers to better understand bird populations and distributions.")
            .font(.body)
          
          Link(
            destination : URL(string: "https://ebird.org/about")!
          )
          {
            HStack
            {
              Image(systemName: "link.circle.fill")
              Text("Learn More About eBird")
              
            } // HStack
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
          } // Link
          .padding(.top, 20)
          
        } // VStack
        .padding()
        
      } // ScrollView
      .navigationBarTitleDisplayMode(.inline)
      .toolbar
      {
        ToolbarItem(
          placement : .confirmationAction
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
  
} // AbouteBirdView
