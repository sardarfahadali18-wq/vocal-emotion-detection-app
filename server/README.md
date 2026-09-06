# Emotion Analysis Server

This is a Flask server that analyzes audio files to detect emotions.

## Setup and Installation

1. **Prerequisites**:

   - Python 3.8 or newer
   - pip package manager

2. **Create a virtual environment** (recommended):

   ```bash
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
   ```bash
   pip install -r requirements.txt
   ```

## Running the Server

1. **Start the Flask server**:

   ```bash
   python app.py
   ```

   This will start the server on port 5000.

2. **Make the server accessible remotely** (for testing):
   - Install ngrok: https://ngrok.com/download
   - Run ngrok to expose your local server:
     ```
     ngrok http 5000
     ```
   - Use the HTTPS URL provided by ngrok in your Flutter app

## API Usage

- **Endpoint**: `/analyze_emotion`
- **Method**: POST
- **Form Parameter**: `audio` (audio file)
- **Response**: JSON object with emotion labels and their confidence scores (percentage)

## Deploy to Production

For production use, consider deploying the server to:

- Heroku
- Google Cloud Run
- AWS Elastic Beanstalk
- DigitalOcean App Platform

Remember to update the URL in your Flutter app to point to your production server.
