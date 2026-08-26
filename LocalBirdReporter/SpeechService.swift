//
//  SpeechService.swift
//  LocalBirdReporter
//
//  Created by Stewart French on 8/6/26.
//

import Foundation
import AVFoundation
import AVFAudio

// ----------------------------------------

class SpeechService
{
  private let synthesizer : AVSpeechSynthesizer = AVSpeechSynthesizer()
  var selectedVoiceIdentifier: String?
  
  // ------------------------------
  // Get available English voices

  static func getAvailableVoices() -> [AVSpeechSynthesisVoice]
  {
    let allEnglishVoices = AVSpeechSynthesisVoice.speechVoices().filter
    {
      $0.language.hasPrefix("en")
    }
    
    // Remove duplicates by keeping first occurrence of each name
    var seenNames = Set<String>()
    return allEnglishVoices.filter { voice in
      if seenNames.contains(voice.name) {
        return false
      } else {
        seenNames.insert(voice.name)
        return true
      }
    }
  } // getAvailableVoices
  
  // ------------------------------
  // Speak a single bird name

  func speak(
    _ text: String
  )
  {
    // Configure audio session for speech
    // Use mixWithOthers to allow silent background audio to continue

    do
    {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode    : .voicePrompt,
        options : [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    }
    catch
    {
      print("Failed to set up audio session: \(error)")
    } // catch
    
    let utterance = AVSpeechUtterance(string: text)
    
    // Use selected voice or default to en-US
    
    if let voiceId = selectedVoiceIdentifier,
       let voice = AVSpeechSynthesisVoice(identifier: voiceId)
    {
      utterance.voice = voice
    }
    else
    {
      utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    }
    
    utterance.rate = 0.5
    synthesizer.speak(utterance)
  } // speak
  
  // ------------------------------
  // Speak bird observations with counts

  func speakBirds(
    _ birds: [BirdObservation]
  )
  {
    guard !birds.isEmpty
    else
    {
      return
    } // else
    
    // Build speech text with bird name and count

    var speechParts: [String] = []

    for bird in birds
    {
      var birdText = bird.comName

      if let count = bird.howMany
      {
        birdText += ", \(count)"
      } // if
      
      speechParts.append(birdText)
    } // for
    
    let combinedText = speechParts.joined(separator: ". ")
    speak(combinedText)
  } // speakBirds
  
  // ------------------------------
  // Stop any ongoing speech

  func stopSpeaking()
  {
    synthesizer.stopSpeaking(at: .immediate)
  } // stopSpeaking
} // class SpeechService
