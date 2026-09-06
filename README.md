# Voice Emotion Analyzer

A Flutter application that records voice and analyzes emotions in speech.

## Key Features

- Audio recording with adjustable duration
- Emotion detection through speech analysis
- Visualization of detected emotions with charts
- Playback of recorded audio
- Saving and managing recordings

## Getting Started

### Setting Up the Flutter App

1. **Install Flutter**:

   - Follow the installation guide at [flutter.dev](https://flutter.dev/docs/get-started/install)

2. **Clone this repository**:

   ```
   git clone https://your-repository-url.git
   cd vocal_emotion_app
   ```

3. **Install dependencies**:

   ```
   flutter pub get
   ```

4. **Run the app**:
   ```
   flutter run
   ```

### Setting Up the Python Server (Required for Android Devices)

Since Python scripts cannot run directly on Android, the app uses a server-based approach for emotion analysis on Android devices.

1. **Navigate to the server directory**:

   ```
   cd server
   ```

2. **Set up a Python virtual environment**:

   ```
   python -m venv venv
   ```

3. **Activate the virtual environment**:

   - On Windows:
     ```
     venv\Scripts\activate
     ```
   - On macOS/Linux:
     ```
     source venv/bin/activate
     ```

4. **Install dependencies**:

   ```
   pip install -r requirements.txt
   ```

5. **Run the server**:
   ```
   python app.py
   ```
   This starts the server on port 5000.

### Connecting the App to the Server

1. **For testing on the same network**:

   - Find your computer's IP address
   - In the app, tap the Settings icon and enter: `http://YOUR_IP_ADDRESS:5000`

2. **For public testing**:

   - Use a service like [ngrok](https://ngrok.com/) to expose your local server:
     ```
     ngrok http 5000
     ```
   - In the app, tap Settings and enter the ngrok URL (https://xxx-xxx-xxx.ngrok.io)

3. **For production**:
   - Deploy the server to a cloud platform (Heroku, AWS, Google Cloud, etc.)
   - Update the app to use your cloud server URL

## Technologies Used

- **Flutter** for the mobile app
- **record** package for audio recording
- **fl_chart** for emotion visualization
- **Flask** for the Python API server
- **transformers** with wav2vec2 model for emotion detection

## Notes

- Python-based emotion analysis works directly on Windows/macOS/Linux
- For Android devices, the server-based approach is necessary
- The minimum Android SDK version required is 23 (Android 6.0)
