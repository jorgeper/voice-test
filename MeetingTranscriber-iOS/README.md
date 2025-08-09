### MeetingTranscriber iOS (SwiftUI)

Minimal, modern iPhone app for real-time meeting transcription with speaker diarization using Azure Speech.

#### Features
- Start/Pause/Stop with a single top-right button
- Real-time transcript stream filling the screen
- Designed for iOS Human Interface Guidelines

#### Prereqs
- Xcode 15+
- iOS 16+
- CocoaPods
- Azure Speech resource (key and region/endpoint)

#### Setup
1. Install CocoaPods if needed: `sudo gem install cocoapods`
2. Install XcodeGen: `brew install xcodegen`
3. Create a `Podfile` in this directory (see below) and run `pod install`.
4. Generate the project: `xcodegen generate`
5. Open `MeetingTranscriber-iOS/MeetingTranscriber.xcworkspace` in Xcode.

#### Podfile template
```
platform :ios, '16.0'
use_frameworks!

target 'MeetingTranscriber' do
  pod 'MicrosoftCognitiveServicesSpeech-iOS'
end
```

Run:
```
pod install
```

Then open the generated `.xcworkspace`.

#### Configure credentials
In Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
- `SPEECH_KEY` = your Azure Speech key
- `SPEECH_REGION` = your Azure region (e.g. `eastus`) or set `ENDPOINT` instead

Alternatively, add a `Secrets.xcconfig` and reference from project build settings.

#### Wiring Azure Speech SDK
This template includes `AzureTranscriber.swift` wired to `TranscriptManager`. After pods install, the SDK is used automatically.

Refer: Microsoft Docs "Real-time diarization quickstart" for event names and properties.

