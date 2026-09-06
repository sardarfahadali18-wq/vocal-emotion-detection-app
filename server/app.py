from flask import Flask, request, jsonify, send_from_directory
import os
import json
import time
import traceback
import logging
import librosa
import torch
from transformers import pipeline
from datetime import datetime
import sys
import socket

app = Flask(__name__)

# Setup logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    handlers=[logging.FileHandler("server.log"),
                              logging.StreamHandler()])
logger = logging.getLogger(__name__)

# Get the server's IP addresses
def get_ip_addresses():
    """Get all IP addresses for this machine"""
    ip_list = []
    
    # Get the hostname
    hostname = socket.gethostname()
    ip_list.append(f"Hostname: {hostname}")
    
    # Get the primary IP by creating a temporary socket connection
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        primary_ip = s.getsockname()[0]
        s.close()
        ip_list.append(f"Primary IP: {primary_ip}")
    except:
        pass
    
    # Get all network interfaces
    try:
        ip_list.append("All network interfaces:")
        interfaces = socket.getaddrinfo(socket.gethostname(), None)
        for interface in interfaces:
            addr = interface[4][0]
            if not addr.startswith('127.') and ':' not in addr:  # Skip loopback and IPv6
                ip_list.append(f"  - {addr}")
    except:
        pass
    
    return ip_list

# Set global exception handler to prevent flask from exiting
def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return
    
    logger.critical("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))

sys.excepthook = handle_exception

# Ensure the uploads directory exists
UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Global variable to store the classifier
classifier = None

# Preload the model at server startup
logger.info("Preloading emotion recognition model...")
try:
    # Use the model that works for the user
    model_name = "superb/wav2vec2-base-superb-er"
    classifier = pipeline(
        "audio-classification", 
        model=model_name,
        framework="pt"  # Explicitly use PyTorch
    )
    logger.info("Model loaded successfully!")
except Exception as e:
    error_details = traceback.format_exc()
    logger.error(f"Error loading model: {str(e)}\n{error_details}")
    classifier = None

def detect_emotion(audio_file):
    """
    Detect emotion from an audio file using Hugging Face Transformers.
    
    Args:
        audio_file: Path to the audio file
    
    Returns:
        Dictionary with emotions and confidence scores
    """
    try:
        # Log audio file information
        logger.info(f"Processing audio file: {audio_file}, size: {os.path.getsize(audio_file)} bytes")
        
        # Load audio file - simplified to match user's working code
        speech_array, sampling_rate = librosa.load(audio_file, sr=16000)
        logger.info(f"Audio loaded successfully, array length: {len(speech_array)}")
        
        # Get emotion predictions
        logger.info("Running classifier on audio")
        preds = classifier(speech_array)
        logger.info(f"Classifier returned {len(preds)} predictions")
        
        # Get the top 3 emotions with their confidence scores
        top_emotions = preds[:3]
        
        # Format the emotion results
        result = {}
        for emotion in top_emotions:
            # Store the raw score (as percentage) for JSON serialization
            result[emotion["label"]] = round(emotion['score'] * 100, 1)
        
        logger.info(f"Emotion detection results: {result}")
        return result
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Error in detect_emotion: {str(e)}\n{error_details}")
        raise

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint to check if server is running and model is loaded."""
    try:
        if classifier is not None:
            return jsonify({"status": "healthy", "model_loaded": True})
        else:
            return jsonify({"status": "unhealthy", "model_loaded": False}), 500
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Error in health check: {str(e)}\n{error_details}")
        return jsonify({"status": "error", "error": str(e)}), 500

@app.route('/analyze_emotion', methods=['POST'])
def analyze_emotion():
    start_time = time.time()
    logger.info("Received analysis request")
    
    try:
        if classifier is None:
            logger.error("Model not loaded")
            return jsonify({'error': 'Model not loaded. Server initialization failed.'}), 500
            
        if 'audio' not in request.files:
            logger.error("No audio file provided")
            return jsonify({'error': 'No audio file provided'}), 400
            
        audio_file = request.files['audio']
        logger.info(f"Processing file: {audio_file.filename}, size: {request.content_length} bytes")
        
        # Add timestamp to filename to avoid conflicts
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{timestamp}_{audio_file.filename}"
        
        # Save the uploaded file to the uploads folder
        temp_path = os.path.join(UPLOAD_FOLDER, filename)
        audio_file.save(temp_path)
        logger.info(f"File saved to {temp_path}")
        
        try:
            # Start timing the processing
            process_start = time.time()
            logger.info("Starting emotion analysis")
            
            # Use the detect_emotion function from the script
            emotions = detect_emotion(temp_path)
            
            process_time = time.time() - process_start
            logger.info(f"Emotion analysis completed in {process_time:.2f} seconds")
            
            # Log both the raw data and formatted results
            logger.info(f"Raw analysis results: {emotions}")
            
            # Format the results for display logs only (doesn't affect the JSON response)
            display_results = {}
            for emotion, score in emotions.items():
                display_results[emotion] = f"{score:.1f}%"
            logger.info(f"Formatted results for display: {display_results}")
            
            total_time = time.time() - start_time
            logger.info(f"Total processing time: {total_time:.2f} seconds")
            
            # Create a response with both the emotion results and file information
            result = {
                'emotions': emotions,
                'file_saved': temp_path,
                'status': 'success'
            }
            
            # Log the actual response being sent to the client
            logger.info(f"Sending response: {json.dumps(result)}")
            
            return jsonify(result)
        except Exception as e:
            # Log detailed error
            error_details = traceback.format_exc()
            logger.error(f"Error analyzing audio: {str(e)}\n{error_details}")
            
            # Don't delete the file even on error - keep it for debugging
            error_response = {
                'error': str(e),
                'details': "Server encountered an error processing the audio. Check server logs for details.",
                'file_saved': temp_path,
                'status': 'error'
            }
            logger.error(f"Sending error response: {json.dumps(error_response)}")
            
            return jsonify(error_response), 500
    except Exception as e:
        # Catch any uncaught exceptions to prevent server from crashing
        error_details = traceback.format_exc()
        logger.error(f"Uncaught exception in analyze_emotion: {str(e)}\n{error_details}")
        
        error_response = {
            'error': str(e),
            'details': "Server encountered an unexpected error. Check server logs for details.",
            'status': 'error'
        }
        
        return jsonify(error_response), 500

@app.route('/stream/<filename>', methods=['GET'])
def stream_audio(filename):
    """Endpoint to stream saved audio files back to clients."""
    try:
        if not os.path.exists(UPLOAD_FOLDER):
            logger.error(f"Upload folder {UPLOAD_FOLDER} does not exist")
            return jsonify({"error": "Upload folder not found"}), 404
        
        # Check if file exists in the uploads folder
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        if not os.path.isfile(file_path):
            logger.error(f"File {filename} not found in uploads folder")
            return jsonify({"error": "File not found"}), 404
        
        logger.info(f"Streaming file: {filename}")
        
        # Stream the file to the client
        return send_from_directory(UPLOAD_FOLDER, filename, mimetype='audio/wav')
    
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Error streaming file {filename}: {str(e)}\n{error_details}")
        return jsonify({"error": str(e)}), 500

@app.route('/recordings', methods=['GET'])
def list_recordings():
    """Endpoint to list all available recordings on the server."""
    try:
        if not os.path.exists(UPLOAD_FOLDER):
            logger.error(f"Upload folder {UPLOAD_FOLDER} does not exist")
            return jsonify({"error": "Upload folder not found"}), 404
        
        recordings = []
        for file in os.listdir(UPLOAD_FOLDER):
            if file.endswith('.wav'):
                file_path = os.path.join(UPLOAD_FOLDER, file)
                file_stat = os.stat(file_path)
                
                # Get file size in KB
                file_size_kb = round(file_stat.st_size / 1024, 2)
                
                # Get creation time
                creation_time = datetime.fromtimestamp(file_stat.st_ctime).isoformat()
                
                recordings.append({
                    'filename': file,
                    'path': file_path,
                    'size_kb': file_size_kb,
                    'created_at': creation_time,
                    'stream_url': f'/stream/{file}'
                })
        
        # Sort by creation time, newest first
        recordings.sort(key=lambda x: x['created_at'], reverse=True)
        
        logger.info(f"Found {len(recordings)} recordings")
        return jsonify({"recordings": recordings})
    
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Error listing recordings: {str(e)}\n{error_details}")
        return jsonify({"error": str(e)}), 500

@app.route('/analyze_server_file', methods=['POST'])
def analyze_server_file():
    """Endpoint to analyze a file that's already on the server."""
    start_time = time.time()
    logger.info("Received request to analyze server file")
    
    try:
        if classifier is None:
            logger.error("Model not loaded")
            return jsonify({'error': 'Model not loaded. Server initialization failed.'}), 500
        
        # Get the filename from request
        filename = request.form.get('filename')
        if not filename:
            logger.error("No filename provided")
            return jsonify({'error': 'No filename provided'}), 400
        
        # Check if file exists
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        if not os.path.isfile(file_path):
            logger.error(f"File {filename} not found in uploads folder")
            return jsonify({'error': 'File not found'}), 404
        
        logger.info(f"Analyzing server file: {filename}")
        
        try:
            # Use the detect_emotion function
            emotions = detect_emotion(file_path)
            
            process_time = time.time() - start_time
            logger.info(f"Server-side analysis completed in {process_time:.2f} seconds")
            
            # Log the results
            logger.info(f"Analysis results: {emotions}")
            
            # Create a response
            result = {
                'emotions': emotions,
                'file_path': file_path,
                'status': 'success'
            }
            
            return jsonify(result)
            
        except Exception as e:
            error_details = traceback.format_exc()
            logger.error(f"Error analyzing server file: {str(e)}\n{error_details}")
            
            return jsonify({
                'error': str(e),
                'details': "Error processing the audio file on server",
                'status': 'error'
            }), 500
            
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Unexpected error in analyze_server_file: {str(e)}\n{error_details}")
        
        return jsonify({
            'error': str(e),
            'details': "Server encountered an unexpected error",
            'status': 'error'
        }), 500

if __name__ == '__main__':
    try:
        # Log all available IP addresses
        ip_list = get_ip_addresses()
        logger.info("Server IP Addresses:")
        for ip in ip_list:
            logger.info(ip)
            print(ip)
        
        print("\nCONFIGURE YOUR FLUTTER APP WITH ONE OF THESE IPs")
        print("Server URL should be: http://<IP_ADDRESS>:5000")
        print("=" * 50)
        
        logger.info("Starting Flask server on port 5000")
        app.run(host='0.0.0.0', port=5000, debug=False, threaded=True) 
    except Exception as e:
        error_details = traceback.format_exc()
        logger.error(f"Error starting server: {str(e)}\n{error_details}") 