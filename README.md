<div align="center">

# 🎙️ Voice Emotion Analyzer

### Real-Time Speech Emotion Recognition powered by Wav2Vec 2.0

A cross-platform Flutter application that records human speech and detects the underlying emotional state using a fine-tuned deep learning model. Built as a Final Year Project at the **International Islamic University Islamabad**.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.x-3776AB?logo=python&logoColor=white)](https://www.python.org)
[![Flask](https://img.shields.io/badge/Flask-Backend-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com)
[![Wav2Vec2](https://img.shields.io/badge/Model-Wav2Vec2-FF6F00)](https://huggingface.co/docs/transformers/model_doc/wav2vec2)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Web-blue)]()
[![License](https://img.shields.io/badge/License-Academic-green)]()

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Model Performance](#-model-performance)
- [Tech Stack](#-tech-stack)
- [Architecture](#-architecture)
- [Getting Started](#-getting-started)
- [Connecting the App to the Server](#-connecting-the-app-to-the-server)
- [Project Structure](#-project-structure)
- [Roadmap](#-roadmap)
- [Team](#-team)
- [License](#-license)

---

## 🔍 Overview

**Voice Emotion Analyzer** is an end-to-end speech emotion recognition (SER) system. Users record their voice through a Flutter mobile/desktop app, and the audio is analyzed by a fine-tuned **Wav2Vec 2.0** transformer model to classify the speaker's emotional state — with results visualized directly in the app.

Unlike traditional SER systems that rely on hand-crafted features, this project leverages self-supervised audio representations, giving the model a deeper understanding of vocal tone, pitch, and rhythm without manual feature engineering.

---

## ✨ Key Features

- 🎤 **Audio Recording** with adjustable duration
- 🧠 **Emotion Detection** from raw speech using a fine-tuned transformer model
- 📊 **Real-Time Visualization** of detected emotions via interactive charts
- ▶️ **Playback** of recorded audio clips
- 💾 **Recording History** — save and manage past recordings
- 🔐 **User Authentication** (Firebase-based login & signup)
- 🌐 **Cross-Platform** — Android, iOS, Windows, macOS, Linux, and Web

---

## 📊 Model Performance

The emotion classification model was fine-tuned on labeled emotional speech data and evaluated on a held-out test set:

| Metric        | Score      |
|---------------|-----------|
| **Accuracy**  | **90.10%** |
| Precision     | 89.19%     |
| Recall        | 89.17%     |
| F1 Score      | 90.66%     |

**Training Configuration**

| Parameter      | Value          |
|----------------|----------------|
| Feature Type   | MFCC           |
| Sample Rate    | 16,000 Hz      |
| Clip Duration  | 3.0 seconds    |
| MFCC Coefficients | 40          |

**Emotions Classified:** `Happy` · `Sad` · `Angry` · `Neutral` · `Fear` · `Disgust` · `Surprise`

> 📈 Confusion matrix and full evaluation results are available in [`MODEL+RESULTS/results/`](./MODEL+RESULTS/results/)

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter (Dart) |
| **Audio Recording** | `record` package |
| **Data Visualization** | `fl_chart` |
| **Backend API** | Flask (Python) |
| **ML Model** | Wav2Vec 2.0 (Hugging Face `transformers`) |
| **Authentication** | Firebase Auth |

---

## 🏗️ Architecture

Since Python/ML inference cannot run natively on mobile devices, the Flutter app communicates with a lightweight Flask server that hosts the trained model and returns predictions over HTTP.

---

## 🚀 Getting Started

### Setting Up the Flutter App

1. **Install Flutter** — follow the guide at [flutter.dev](https://flutter.dev/docs/get-started/install)
2. **Clone this repository**
```bash
   git clone https://github.com/sardarfahadali18-wq/vocal-emotion-detection-app.git
   cd vocal-emotion-detection-app
```
3. **Install dependencies**
```bash
   flutter pub get
```
4. **Run the app**
```bash
   flutter run
```

### Setting Up the Python Server (Required for Android/iOS)

Since Python cannot run directly on mobile devices, the app uses a server-based approach for emotion analysis.

1. **Navigate to the server directory**
```bash
   cd server
```
2. **Set up a Python virtual environment**
```bash
   python -m venv venv
```
3. **Activate the virtual environment**

   Windows:
```bash
   venv\Scripts\activate
```
   macOS/Linux:
```bash
   source venv/bin/activate
```
4. **Install dependencies**
```bash
   pip install -r requirements.txt
```
5. **Run the server**
```bash
   python app.py
```
   The server starts on port `5000`.

---

## 🔗 Connecting the App to the Server

**For local testing (same network):**
- Find your computer's IP address
- In the app, open Settings and enter: `http://YOUR_IP_ADDRESS:5000`

**For public testing:**
- Expose your local server using [ngrok](https://ngrok.com/):
```bash
  ngrok http 5000
```
- Enter the generated ngrok URL in the app's Settings

**For production:**
- Deploy the Flask server to a cloud platform (Heroku, AWS, Google Cloud, etc.)
- Update the app's server URL to point to your deployed endpoint

---

## 📁 Project Structure

---

## 🗺️ Roadmap

- [x] Project planning & dataset research
- [x] Flutter app UI design
- [x] Audio feature extraction module
- [x] ML model training & optimization (90.1% accuracy)
- [x] Flask server integration for on-device inference
- [x] Testing across platforms
- [ ] Cloud deployment of inference server
- [ ] FYP documentation & final presentation

---

## 👥 Team

- **Sardar Fahad Ali** — BS Information Technology, IIUI

---

## 📄 License

This project is developed for academic purposes as part of the Final Year Project at the **International Islamic University Islamabad**.

---

<div align="center">

**⭐ If you found this project interesting, consider giving it a star!**

</div>
