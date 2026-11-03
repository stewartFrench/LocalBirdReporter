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

class SpeechService: NSObject, AVSpeechSynthesizerDelegate
{
  private nonisolated(unsafe) let synthesizer : AVSpeechSynthesizer = AVSpeechSynthesizer()
  var selectedVoiceIdentifier                 : String?
  var onSpeechFinished                        : (() -> Void)?

  // ------------------------------

  override init()
  {
    super.init()
    synthesizer.delegate = self

  } // init

  // ------------------------------

          // Get available English voices

  static func getAvailableVoices() -> [AVSpeechSynthesisVoice]
  {
    let allEnglishVoices = AVSpeechSynthesisVoice.speechVoices().filter
    {
      $0.language.hasPrefix("en")
    } // filter

            // Remove duplicates by keeping first occurrence of each name

    var seenNames = Set<String>()
    return allEnglishVoices.filter
    {
      voice in

      if seenNames.contains(voice.name)
      {
        return false
      } // if
      else
      {
        seenNames.insert(voice.name)
        return true
      } // else
    } // filter
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
    } // do
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
    } // if
    else
    {
      utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    } // else

    utterance.rate = 0.5

            // Give the audio route a moment to engage before speaking.
            // Without this, the first word is sometimes clipped - most
            // noticeable on a cold app launch triggered by Siri, where
            // the audio session has never been activated before

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
    {
      [weak self] in

      self?.synthesizer.speak(utterance)

    } // asyncAfter
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

  // ------------------------------
  // AVSpeechSynthesizerDelegate - the real completion signal, used
  // instead of guessing how long speech will take

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  )
  {
    DispatchQueue.main.async
    {
      [weak self] in

      self?.onSpeechFinished?()

    } // async

  } // speechSynthesizer didFinish

  // ------------------------------

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  )
  {
    DispatchQueue.main.async
    {
      [weak self] in

      self?.onSpeechFinished?()

    } // async

  } // speechSynthesizer didCancel

} // class SpeechService
