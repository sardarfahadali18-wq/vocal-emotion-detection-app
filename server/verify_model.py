#!/usr/bin/env python
"""
Simple script to verify that the model loads and works correctly
"""
import os
import sys
import traceback
import librosa
import torch
from transformers import pipeline

def test_model():
    """Test that the model loads and can process audio"""
    print("Testing emotion recognition model...")
    
    try:
        # Use the model that works for the user
        model_name = "superb/wav2vec2-base-superb-er"
        print(f"Loading model: {model_name}")
        
        classifier = pipeline(
            "audio-classification", 
            model=model_name,
            framework="pt"  # Explicitly use PyTorch
        )
        
        print("Model loaded successfully!")
        
        # See if we have an audio file to test with
        test_file = None
        upload_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
        
        if os.path.exists(upload_dir):
            files = [f for f in os.listdir(upload_dir) if f.endswith(('.wav', '.mp3'))]
            if files:
                test_file = os.path.join(upload_dir, files[0])
                print(f"Found test file: {test_file}")
        
        # If no existing file, create a test audio
        if not test_file:
            print("No test file found, creating a simple tone...")
            import numpy as np
            from scipy.io import wavfile
            
            # Create a simple sine wave
            sample_rate = 16000
            duration = 1.0  # seconds
            freq = 440.0  # Hz (A4)
            t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
            sine_wave = 0.5 * np.sin(2 * np.pi * freq * t)
            
            # Save as WAV file
            test_file = "test_tone.wav"
            wavfile.write(test_file, sample_rate, sine_wave.astype(np.float32))
            print(f"Created test tone: {test_file}")
        
        # Process the audio
        print(f"Loading audio file: {test_file}")
        speech_array, sampling_rate = librosa.load(test_file, sr=16000)
        print(f"Audio loaded, length: {len(speech_array)} samples")
        
        # Run inference
        print("Running inference...")
        preds = classifier(speech_array)
        
        # Display results
        print("\nPrediction results:")
        print("-" * 50)
        
        for pred in preds[:3]:  # Top 3 predictions
            print(f"- {pred['label']}: {pred['score']*100:.2f}%")
        
        print("\nModel verification completed successfully!")
        return True
        
    except Exception as e:
        print(f"Error during model verification: {str(e)}")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_model()
    sys.exit(0 if success else 1) 