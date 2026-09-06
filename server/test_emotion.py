#!/usr/bin/env python
"""
Standalone script to record audio and detect emotions, or analyze an existing audio file.
"""
import pyaudio
import wave
import os
import time
import numpy as np
import librosa
import torch
import argparse
from transformers import pipeline

def record_audio(filename="recording.wav", duration=5, sample_rate=16000):
    """
    Record audio from the microphone for a specified duration.
    
    Args:
        filename: Name of the output audio file
        duration: Duration of recording in seconds
        sample_rate: Sample rate of the recording
    """
    # Audio recording parameters
    chunk = 1024
    audio_format = pyaudio.paInt16
    channels = 1
    
    print(f"Recording for {duration} seconds...")
    
    # Initialize PyAudio
    p = pyaudio.PyAudio()
    
    # Open stream
    stream = p.open(format=audio_format,
                    channels=channels,
                    rate=sample_rate,
                    input=True,
                    frames_per_buffer=chunk)
    
    frames = []
    
    # Record audio in chunks
    for i in range(0, int(sample_rate / chunk * duration)):
        data = stream.read(chunk)
        frames.append(data)
    
    print("Recording finished!")
    
    # Stop and close the stream
    stream.stop_stream()
    stream.close()
    p.terminate()
    
    # Save the recorded audio as a WAV file
    wf = wave.open(filename, 'wb')
    wf.setnchannels(channels)
    wf.setsampwidth(p.get_sample_size(audio_format))
    wf.setframerate(sample_rate)
    wf.writeframes(b''.join(frames))
    wf.close()
    
    print(f"Audio saved as {filename}")
    return filename

def preprocess_audio(audio_file):
    """
    Preprocess audio file to improve emotion detection accuracy
    
    Args:
        audio_file: Path to the audio file
    
    Returns:
        Preprocessed audio array and sampling rate
    """
    # Load audio with librosa
    speech_array, sampling_rate = librosa.load(audio_file, sr=16000)
    
    # Apply noise reduction
    speech_array = librosa.effects.trim(speech_array, top_db=20)[0]
    
    # Normalize audio to have values between -1 and 1
    speech_array = librosa.util.normalize(speech_array)
    
    # Make sure the audio is at least 1 second (16000 samples)
    if len(speech_array) < 16000:
        speech_array = np.pad(speech_array, (0, 16000 - len(speech_array)), 'constant')
    
    return speech_array, sampling_rate

def detect_emotion(audio_file):
    """
    Detect emotion from an audio file using Hugging Face Transformers.
    
    Args:
        audio_file: Path to the audio file
    
    Returns:
        Dictionary with emotions and confidence scores
    """
    print("Loading emotion recognition model...")
    
    # Load and preprocess audio file
    speech_array, sampling_rate = preprocess_audio(audio_file)
    
    # Use a better emotion recognition model
    model_name = "ehcalabres/wav2vec2-lg-xlsr-en-speech-emotion-recognition"
    
    # Initialize the audio classification pipeline with explicit PyTorch backend
    classifier = pipeline(
        "audio-classification", 
        model=model_name,
        framework="pt",  # Explicitly use PyTorch
        device=0 if torch.cuda.is_available() else -1  # Use GPU if available
    )
    
    print("Analyzing your emotion...")
    
    # Get emotion predictions
    preds = classifier(speech_array)
    
    # Get the top 3 emotions with their confidence scores
    top_emotions = preds[:3]
    
    # Format the emotion results
    result = {}
    for emotion in top_emotions:
        # Store the raw score (as percentage)
        result[emotion["label"]] = round(emotion['score'] * 100, 1)
    
    return result

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Emotion Detection from Speech')
    parser.add_argument('--file', type=str, help='Path to an existing audio file to analyze')
    parser.add_argument('--duration', type=int, default=5, help='Duration in seconds to record (if not using existing file)')
    parser.add_argument('--list', action='store_true', help='List all available audio files in uploads directory')
    args = parser.parse_args()
    
    print("Emotion Detection from Speech")
    print("=============================")
    
    if args.list:
        # List all audio files in the uploads directory
        upload_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
        if os.path.exists(upload_dir):
            files = [f for f in os.listdir(upload_dir) if f.endswith(('.wav', '.mp3'))]
            print(f"\nFound {len(files)} audio files in {upload_dir}:")
            for i, file in enumerate(files):
                print(f"{i+1}. {file}")
        else:
            print(f"Uploads directory {upload_dir} not found.")
        return
    
    if args.file:
        # Use existing audio file
        if not os.path.exists(args.file):
            print(f"Error: File {args.file} does not exist")
            return
        
        print(f"Using existing file: {args.file}")
        audio_file = args.file
    else:
        # Record audio from the microphone
        audio_file = record_audio(duration=args.duration)
    
    # Detect emotion from the audio
    emotions = detect_emotion(audio_file)
    
    print("\nResults:")
    print("========")
    print("Detected emotions:")
    for emotion, score in emotions.items():
        print(f"- {emotion}: {score:.1f}%")

if __name__ == "__main__":
    main() 