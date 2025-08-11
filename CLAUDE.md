# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dual-platform voice transcription project with:
- **Python Application**: Real-time conversation transcription with speaker diarization
- **iOS Application**: SwiftUI app for meeting transcription on iPhone

Both applications use Azure Cognitive Services Speech SDK for speech recognition and synthesis.

## Common Development Commands

### Python Application

```bash
# Setup virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run transcriber from microphone
python conversation_transcriber.py --mode microphone

# Run transcriber from audio file
python conversation_transcriber.py --mode file --input audio.wav

# Generate synthetic conversation
python conversation_transcriber.py --mode random --duration 60 --output test.md

# Convert markdown to audio
python conversation_transcriber.py --mode generate --input convo.md --output audio.wav

# Run tests
python test_setup.py
python test_end_to_end.py
```

### iOS Application

```bash
cd MeetingTranscriber-iOS

# Initial setup
brew install xcodegen cocoapods
xcodegen generate
pod install

# Set environment variables in Xcode scheme
chmod +x Scripts/set_env.sh
./Scripts/set_env.sh

# Build from command line
xcodebuild -workspace MeetingTranscriber.xcworkspace -scheme MeetingTranscriber -configuration Debug build

# Open in Xcode
open MeetingTranscriber.xcworkspace
```

## Environment Setup

Required environment variables:
- `AZURE_SPEECH_KEY`: Your Azure Speech Service API key
- `AZURE_SPEECH_REGION`: Azure region (e.g., "eastus")

## Architecture

### Python Application Structure
```
├── conversation_transcriber.py  # Main entry point with CLI interface
├── transcriber.py              # Core transcription logic and Azure SDK integration
├── generator.py                # Text-to-speech and conversation generation
├── utils.py                    # Audio processing utilities
└── config.yaml                 # Speaker voice configuration
```

### iOS Application Structure
```
MeetingTranscriber-iOS/
├── MeetingTranscriber/
│   ├── Models/
│   │   └── TranscriptEntry.swift    # Data model for transcript entries
│   ├── Views/
│   │   ├── ContentView.swift        # Main app view
│   │   ├── MainView.swift           # Transcription interface
│   │   └── SettingsView.swift       # App settings
│   ├── AzureTranscriber.swift       # Azure SDK integration
│   └── TranscriptManager.swift      # State management
└── project.yml                      # XcodeGen configuration
```

## Implementation Best Practices

### Python Development

1. **Function Design**
   - Keep functions focused on a single responsibility
   - Use type hints for all function parameters and returns
   - Handle Azure SDK exceptions gracefully
   - Separate audio processing from transcription logic

2. **Error Handling**
   - Always catch and handle `azure.cognitiveservices.speech` exceptions
   - Provide clear error messages for configuration issues
   - Validate audio input formats before processing

3. **Testing**
   - Test audio processing functions with sample audio files
   - Mock Azure SDK calls for unit tests
   - Use `test_setup.py` to verify environment configuration

### iOS Development

1. **SwiftUI Best Practices**
   - Use `@StateObject` for view models
   - Implement proper error handling for microphone permissions
   - Follow MVVM architecture pattern
   - Use `Task` for async operations

2. **Azure SDK Integration**
   - Handle speech recognition events on main thread for UI updates
   - Properly manage speech recognizer lifecycle
   - Implement reconnection logic for network issues

3. **Memory Management**
   - Stop recognition when view disappears
   - Clean up audio sessions properly
   - Limit transcript history to prevent memory issues

## Key Technologies

### Python Dependencies
- `azure-cognitiveservices-speech`: Speech recognition and synthesis
- `pyaudio`: Cross-platform audio I/O
- `pydub`: Audio file manipulation
- `numpy`: Audio data processing
- `rich`: Terminal UI formatting
- `openai`: AI text generation for synthetic conversations

### iOS Dependencies
- `MicrosoftCognitiveServicesSpeech-iOS`: Azure Speech SDK
- SwiftUI: Modern declarative UI framework
- AVFoundation: Audio session management

## Configuration Files

### config.yaml
Defines speaker voices for text-to-speech:
```yaml
speakers:
  Alice: 
    voice: en-US-JennyNeural
    rate: 1.0
    pitch: 0
  Bob:
    voice: en-US-GuyNeural
    rate: 0.9
    pitch: -2
```

### project.yml
XcodeGen configuration for iOS project generation. Modify deployment targets and bundle identifiers here.

## Common Tasks

### Adding a New Speaker Voice
1. Edit `config.yaml` to add speaker configuration
2. Use Azure's voice gallery to find voice names
3. Test with: `python conversation_transcriber.py --mode generate --input test.md`

### Debugging Audio Issues
1. Python: Check microphone permissions and PyAudio device list
2. iOS: Verify Info.plist has microphone usage description
3. Both: Ensure audio format is compatible (16kHz, 16-bit, mono)

### Updating Azure SDK
1. Python: Update version in `requirements.txt`
2. iOS: Update version in `Podfile` and run `pod update`

## Testing Approach

### Python Testing
- Unit tests for audio utilities in `utils.py`
- Integration tests for transcription in `test_end_to_end.py`
- Manual testing with various audio formats and microphones

### iOS Testing
- UI testing for transcription flow
- Unit tests for TranscriptManager logic
- Test on real devices for microphone permissions

## Performance Considerations

1. **Audio Processing**
   - Use appropriate sample rates (16kHz for speech)
   - Process audio in chunks to reduce latency
   - Implement proper audio level detection

2. **Network**
   - Handle intermittent connectivity gracefully
   - Batch recognition results to reduce UI updates
   - Implement exponential backoff for retries

3. **UI Responsiveness**
   - Update UI on main thread only
   - Limit transcript history display
   - Use virtualized lists for long transcripts