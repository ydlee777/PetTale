# Oreamy temporary audio recording

Step 2A records voice notes as MPEG-4 Audio (`.m4a`) containing mono AAC at 44.1 kHz, 64 kbps, high encoder quality. This is a compact Apple-native speech format that preserves clear voice input and can be decoded by AVFoundation for the later SpeechAnalyzer pipeline.

Each recording uses a UUID-named file in the application temporary directory. The file is never added to SwiftData, CloudKit, Documents, or the backend. Record Again deletes the reviewed file before creating another; Discard and abandoned recording screens delete it immediately. Backgrounding or an audio interruption safely stops an active recording into review, while dismissing the flow cleans it up. During Step 2B the session retains the temporary file through transcript review so Record Again and explicit discard remain reliable; completing or abandoning the flow deletes it.
