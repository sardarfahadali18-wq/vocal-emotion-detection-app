import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'splash_screen.dart'; // Import the splash screen
import 'tab_navigator.dart'; // Import the tab navigator
import 'login_screen.dart'; // Import for AppColors
import 'package:shared_preferences/shared_preferences.dart';

/// Standardized app colors for consistent emotion representation
class AppColors {
  // Main app theme colors
  static const primaryColor = Color(0xFF673AB7);
  static const accentColor = Color(0xFFFF9800);
  static const backgroundColor = Colors.white;

  // Emotion colors - standardized across the app
  static Color getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
      case 'hap':
        return Colors.amber; // Darker yellow/gold color that's more readable
      case 'sad':
      case 'sadness':
        return Colors.blue;
      case 'angry':
      case 'anger':
      case 'ang':
        return Colors.red;
      case 'fear':
      case 'fearful':
        return Colors.purple;
      case 'disgust':
      case 'disgusted':
        return Colors.brown;
      case 'surprise':
      case 'surprised':
        return Colors.orange;
      case 'neutral':
      case 'neu':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Get full emotion name for display
  static String getFullEmotionName(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'hap':
        return 'Happy';
      case 'sad':
        return 'Sad';
      case 'angry':
      case 'ang':
        return 'Angry';
      case 'fear':
        return 'Fear';
      case 'disgust':
        return 'Disgust';
      case 'surprise':
        return 'Surprise';
      case 'neutral':
      case 'neu':
        return 'Neutral';
      default:
        return emotion.isNotEmpty
            ? emotion[0].toUpperCase() + emotion.substring(1)
            : 'Unknown';
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check only for mobile platforms
  try {
    if (!kIsWeb) {
      // Skip Firebase App Check completely for web
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
    }
  } catch (e) {
    // Catch and print any App Check initialization errors
    print('Firebase App Check initialization error: $e');
    // Continue with the app regardless of App Check initialization status
  }

  runApp(const VoiceEmotionApp());
}

class VoiceEmotionApp extends StatelessWidget {
  const VoiceEmotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Speech Emotion Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Montserrat',
      ),
      home: const SplashScreen(), // Start with the splash screen
    );
  }
}

class RecorderPage extends StatefulWidget {
  final String? serverUrl;

  const RecorderPage({super.key, this.serverUrl});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isAnalyzing = false;
  bool _isPlaying = false;
  String? _recordPath;
  String? _currentlyPlayingPath;
  List<String> _recordings = [];
  Map<String, double> _emotionResults = {};
  String _status = 'Ready to record';
  int _recordingDuration = 5; // Default recording duration in seconds
  String _serverUrl =
      'http://192.168.228.12:5000'; // Updated with the correct IP
  final TextEditingController _serverUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _requestPermission();
    _createPythonScript();
    _loadServerUrl();

    // Initialize server URL from widget or use default
    if (widget.serverUrl != null && widget.serverUrl!.isNotEmpty) {
      _serverUrl = widget.serverUrl!;
    }
    _serverUrlController.text = _serverUrl;

    // Set up audio player completion listener
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingPath = null;
        _status = 'Playback finished';
      });
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  // Create the Python script in the app's documents directory
  Future<void> _createPythonScript() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final scriptPath = '${directory.path}/emotion_detector.py';
      final file = File(scriptPath);

      // Check if file already exists
      if (!await file.exists()) {
        await file.writeAsString('''
import sys
import os
import json
import librosa
import torch
from transformers import pipeline

def analyze_emotion(audio_file, output_file):
    try:
        # Use a public emotion recognition model
        model_name = "superb/wav2vec2-base-superb-er"
        
        # Initialize the classifier
        classifier = pipeline(
            "audio-classification", 
            model=model_name,
            framework="pt"
        )
        
        # Load audio file
        speech_array, sampling_rate = librosa.load(audio_file, sr=16000)
        
        # Get emotion predictions
        preds = classifier(speech_array)
        
        # Get the top 3 emotions with their confidence scores
        top_emotions = preds[:3]
        
        # Format the emotion results
        emotions = {}
        for emotion in top_emotions:
            emotions[emotion["label"]] = emotion['score'] * 100
        
        # Write results to output file
        with open(output_file, 'w') as f:
            json.dump(emotions, f)
            
        return True
    except Exception as e:
        with open(output_file, 'w') as f:
            json.dump({"error": str(e)}, f)
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python emotion_detector.py <audio_file> <output_file>")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = sys.argv[2]
    
    success = analyze_emotion(audio_file, output_file)
    sys.exit(0 if success else 1)
''');
      }
    } catch (e) {
      setState(() {
        _status = 'Error creating Python script: $e';
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() {
        _status = 'Microphone permission is required!';
      });
    }
  }

  Future<void> _loadRecordings() async {
    final directory = await getApplicationDocumentsDirectory();
    final dir = Directory('${directory.path}/recordings');

    debugPrint('App recordings directory: ${dir.path}');

    if (await dir.exists()) {
      final files = await dir.list().toList();
      final wavFiles =
          files.where((file) => file.path.endsWith('.wav')).toList();

      debugPrint('Found ${wavFiles.length} WAV files in main.dart');

      // Log file paths
      for (var file in wavFiles) {
        debugPrint('Recording file: ${file.path}');
      }

      setState(() {
        _recordings = wavFiles.map((file) => file.path).toList();
      });
    } else {
      debugPrint('Creating recordings directory for the first time');
      await dir.create(recursive: true);
    }
  }

  Future<void> _startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      if (!await recordingsDir.exists()) {
        debugPrint('Creating recordings directory: ${recordingsDir.path}');
        await recordingsDir.create(recursive: true);
      } else {
        debugPrint('Recordings directory exists: ${recordingsDir.path}');
      }

      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordPath = '${recordingsDir.path}/$fileName';

      debugPrint('About to record to: $_recordPath');

      // Check microphone permission using permission_handler
      if (await Permission.microphone.isGranted) {
        // Get ready to record audio with better settings
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
        }

        // Configure with settings matching the Python code - updated for record 5.1.2
        final config = RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 256000,
          sampleRate: 16000, // Match the sample rate in the Python code
        );

        await _audioRecorder.start(config, path: _recordPath!);

        debugPrint('Started recording to: $_recordPath');

        setState(() {
          _status = 'Recording for $_recordingDuration seconds... Speak now';
          _isRecording = true;
          _isPaused = false;
          _emotionResults = {}; // Clear previous results
        });

        // Automatically stop after the set duration
        Future.delayed(Duration(seconds: _recordingDuration), () {
          if (_isRecording && !_isPaused) {
            _stopRecording();
          }
        });
      } else {
        setState(() {
          _status = 'Microphone permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error starting recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      debugPrint('Recording stopped. Path returned: $path');

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _status = 'Recording stopped';
      });

      if (path != null) {
        // Check if file exists and has valid size
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          debugPrint('File exists with size: ${fileSize} bytes');

          if (fileSize > 1000) {
            // Check if file is not too small (empty)
            // Refresh the recordings list
            await _loadRecordings();

            setState(() {
              _status =
                  'Recording saved: ${(fileSize / 1024).toStringAsFixed(2)} KB';
            });

            // Automatically analyze the recording
            await _analyzeEmotion(path);
          } else {
            debugPrint('Warning: Recording file is too small: $fileSize bytes');
            setState(() {
              _status =
                  'Warning: Recording file is too small. Please try speaking louder';
            });
            // Add it anyway in case it contains something
            await _loadRecordings();
          }
        } else {
          debugPrint('Error: Recording file does not exist at path: $path');
          setState(() {
            _status = 'Error: Recording file not found';
          });
        }
      } else {
        debugPrint('Error: No path returned from recorder');
        setState(() {
          _status = 'Error: No recording path returned';
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _status = 'Error stopping recording: $e';
      });
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() {
        _isPaused = true;
        _status = 'Recording paused';
      });
    } catch (e) {
      setState(() {
        _status = 'Error pausing recording: $e';
      });
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() {
        _isPaused = false;
        _status = 'Recording resumed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error resuming recording: $e';
      });
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      // First stop any currently playing audio
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      // Show file info before playing
      final file = File(path);
      if (await file.exists()) {
        final fileSize = await file.length();

        // Play the audio file
        final source = DeviceFileSource(path);
        await _audioPlayer.play(source);

        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = path;
          _status = 'Playing: ${(fileSize / 1024).toStringAsFixed(2)} KB';
        });
      } else {
        setState(() {
          _status = 'Error: Audio file not found';
        });
      }
    } catch (e) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingPath = null;
        _status = 'Error playing recording: $e';
      });
    }
  }

  Future<void> _deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        setState(() {
          _recordings.remove(path);
          _status = 'Recording deleted';
          // Clear emotion results if this was the analyzed file
          if (_emotionResults.isNotEmpty) {
            _emotionResults = {};
          }
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error deleting recording: $e';
      });
    }
  }

  String _getFileName(String path) {
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }

  Future<void> _analyzeEmotion(String path) async {
    try {
      setState(() {
        _isAnalyzing = true;
        _status = 'Analyzing emotions...';
        _emotionResults = {}; // Clear previous results
      });

      // For both Android and other platforms, use API
      await _analyzeEmotionUsingAPI(path);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _status = 'Error analyzing emotion: $e';
      });
    }
  }

  Future<void> _analyzeEmotionUsingAPI(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        setState(() {
          _isAnalyzing = false;
          _status = 'Error: Audio file not found';
        });
        return;
      }

      // First check if the server is healthy
      setState(() {
        _status = 'Checking server connection...';
      });

      final healthUrl = '$_serverUrl/health';

      try {
        final healthResponse = await http
            .get(Uri.parse(healthUrl))
            .timeout(const Duration(seconds: 5));

        if (healthResponse.statusCode != 200) {
          setState(() {
            _isAnalyzing = false;
            _status =
                'Server health check failed: Server may be starting up, please try again in a moment';
          });
          return;
        }
      } catch (e) {
        setState(() {
          _isAnalyzing = false;
          _status =
              'Server connection failed: Make sure the server is running at $_serverUrl';
        });
        return;
      }

      // Show the URL being used to help debug
      setState(() {
        _status = 'Connecting to: ${_serverUrl}/analyze_emotion';
      });

      // Get file size for better status updates
      final fileSize = await file.length();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);

      // Use the server URL from the controller
      final apiUrl = '${_serverUrl}/analyze_emotion';

      setState(() {
        _status = 'Preparing audio file (${fileSizeKB} KB)...';
      });

      // Create a multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Attach the audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      setState(() {
        _status = 'Sending audio to server and waiting for analysis...';
      });

      // Send the request with a longer timeout for larger files
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60), // Much longer timeout
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out after 60 seconds. The server might be busy or the file might be too large.');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Log the full response for debugging
        print('Server response: $responseData');

        // Extract the saved file path (for information only)
        final String? savedFilePath = responseData['file_saved'];

        // Extract emotion results
        Map<String, dynamic>? emotionsData = responseData['emotions'];

        if (emotionsData == null) {
          // Fall back to the whole response if 'emotions' key is not found
          emotionsData = responseData;
        }

        // Convert to the expected format
        final Map<String, double> emotions = {};
        emotionsData.forEach((key, value) {
          if (value is num) {
            emotions[key] = value.toDouble();
          } else if (value is String) {
            try {
              emotions[key] = double.parse(value);
            } catch (e) {
              print('Error parsing emotion value: $e');
            }
          }
        });

        if (emotions.isEmpty) {
          setState(() {
            _isAnalyzing = false;
            _status =
                'Error: No valid emotion data in server response. Check server logs.';
          });
          return;
        }

        setState(() {
          _emotionResults = emotions;
          _isAnalyzing = false;
          _status = savedFilePath != null
              ? 'Analysis complete. File saved on server.'
              : 'Emotion analysis complete';
        });
      } else {
        // Try to extract error information
        Map<String, dynamic>? errorData;
        try {
          errorData = json.decode(response.body);
        } catch (e) {
          // Invalid JSON
        }

        setState(() {
          _isAnalyzing = false;
          if (errorData != null && errorData.containsKey('error')) {
            _status = 'Server error: ${errorData['error']}';
          } else {
            _status = 'Server error: ${response.statusCode} ${response.body}';
          }
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _status =
            'Connection error: $e\nMake sure both devices are on the same network.';
      });
    }
  }

  // Load server URL from SharedPreferences
  Future<void> _loadServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString('server_url');
      if (storedUrl != null && storedUrl.isNotEmpty) {
        setState(() {
          _serverUrl = storedUrl;
        });
      }
    } catch (e) {
      print('Error loading server URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Emotion Analyzer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Recording controls
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Column(
                  children: [
                    // Duration slider
                    Row(
                      children: [
                        const Text('Duration: '),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 20,
                            divisions: 19,
                            value: _recordingDuration.toDouble(),
                            onChanged: (value) {
                              setState(() {
                                _recordingDuration = value.toInt();
                              });
                            },
                            label: '$_recordingDuration seconds',
                          ),
                        ),
                        Text('$_recordingDuration sec'),
                      ],
                    ),
                    // Recording buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!_isRecording)
                          ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic),
                            label: const Text('Record'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _stopRecording,
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isPaused
                                    ? _resumeRecording
                                    : _pauseRecording,
                                icon: Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause),
                                label: Text(_isPaused ? 'Resume' : 'Pause'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status indicator
              Container(
                padding: const EdgeInsets.all(8),
                color: _isRecording
                    ? Colors.red[100]
                    : _isAnalyzing
                        ? Colors.blue[100]
                        : Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isRecording
                          ? (_isPaused ? Icons.pause : Icons.mic)
                          : _isAnalyzing
                              ? Icons.psychology
                              : Icons.info_outline,
                      color: _isRecording
                          ? Colors.red
                          : _isAnalyzing
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: _isRecording
                              ? Colors.red
                              : _isAnalyzing
                                  ? Colors.blue
                                  : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Emotion Results Chart
              if (_emotionResults.isNotEmpty)
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(16),
                  margin:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Detected Emotions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _saveToHistory();
                            },
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save to History',
                                style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(color: Colors.deepPurple),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Column(
                          children: [
                            // Dominant emotion indicator
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _getEmotionColor(_getDominantEmotion())
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'PRIMARY EMOTION',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    AppColors.getFullEmotionName(
                                        _getDominantEmotion()),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _getEmotionColor(
                                          _getDominantEmotion()),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${_emotionResults[_getDominantEmotion()]?.toStringAsFixed(1) ?? "0"}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: _getEmotionColor(
                                          _getDominantEmotion()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Emotion bars
                            Expanded(
                              child: ListView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _emotionResults.length,
                                itemBuilder: (context, index) {
                                  final emotion =
                                      _emotionResults.keys.elementAt(index);
                                  final value =
                                      _emotionResults.values.elementAt(index);
                                  final fullName =
                                      AppColors.getFullEmotionName(emotion);
                                  final color = _getEmotionColor(emotion);

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              fullName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: color,
                                              ),
                                            ),
                                            Text(
                                              '${value.toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Progress bar
                                        Stack(
                                          children: [
                                            // Background
                                            Container(
                                              height: 12,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            // Foreground
                                            Container(
                                              height: 12,
                                              width: (MediaQuery.of(context)
                                                          .size
                                                          .width -
                                                      64) *
                                                  (value / 100),
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        color.withOpacity(0.4),
                                                    blurRadius: 3,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // List of recordings
              Container(
                height: 300, // Fixed height for the recordings list
                child: _recordings.isEmpty
                    ? const Center(
                        child: Text(
                          'No recordings yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _recordings.length,
                        itemBuilder: (context, index) {
                          final path = _recordings[index];
                          final isPlaying = _currentlyPlayingPath == path;

                          return ListTile(
                            leading: const Icon(Icons.audio_file),
                            title: Text(_getFileName(path)),
                            subtitle: isPlaying
                                ? const Text('Playing...',
                                    style: TextStyle(color: Colors.blue))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.stop : Icons.play_arrow,
                                    color: isPlaying ? Colors.red : null,
                                  ),
                                  onPressed: () {
                                    if (isPlaying) {
                                      _audioPlayer.stop();
                                      setState(() {
                                        _isPlaying = false;
                                        _currentlyPlayingPath = null;
                                        _status = 'Playback stopped';
                                      });
                                    } else {
                                      _playRecording(path);
                                    }
                                  },
                                  tooltip: isPlaying ? 'Stop' : 'Play',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.psychology),
                                  onPressed: () => _analyzeEmotion(path),
                                  tooltip: 'Analyze Emotions',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteRecording(path),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEmotionColor(String emotion) {
    return AppColors.getEmotionColor(emotion);
  }

  String _getDominantEmotion() {
    // Implement your logic to determine the dominant emotion
    // For example, you can iterate through the emotion results and find the one with the highest value
    String dominantEmotion = '';
    double maxValue = 0.0;
    _emotionResults.forEach((emotion, value) {
      if (value > maxValue) {
        maxValue = value;
        dominantEmotion = emotion;
      }
    });
    return dominantEmotion;
  }

  void _saveToHistory() {
    // Save the current emotion results to history
    if (_recordPath != null && _emotionResults.isNotEmpty) {
      try {
        // Get the recording file
        final recordingFile = File(_recordPath!);
        if (!recordingFile.existsSync()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording file not found')),
          );
          return;
        }

        // Generate a unique ID for this analysis
        final analysisId = DateTime.now().millisecondsSinceEpoch.toString();

        // Create a directory for storing analysis results if it doesn't exist
        getApplicationDocumentsDirectory().then((directory) async {
          final analysisDir = Directory('${directory.path}/analyses');
          if (!await analysisDir.exists()) {
            await analysisDir.create(recursive: true);
          }

          // Create a JSON file with the analysis results
          final analysisFile =
              File('${analysisDir.path}/analysis_$analysisId.json');

          // Get recording information
          final fileName = _recordPath!.split('/').last;

          // Create a map with all the necessary information
          final analysisData = {
            'id': analysisId,
            'recording_path': _recordPath!,
            'recording_name': fileName,
            'timestamp': DateTime.now().toIso8601String(),
            'emotions': _emotionResults,
            'dominant_emotion': _getDominantEmotion(),
          };

          // Write the JSON file
          await analysisFile.writeAsString(jsonEncode(analysisData));

          debugPrint('Analysis saved to: ${analysisFile.path}');
          debugPrint('Analysis data: ${jsonEncode(analysisData)}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Analysis saved to history'),
              action: SnackBarAction(
                label: 'VIEW',
                onPressed: () {
                  // Navigate to the history tab
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TabNavigator(initialIndex: 1),
                    ),
                  );
                },
              ),
            ),
          );
        });
      } catch (e) {
        debugPrint('Error saving analysis: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving analysis: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recording or analysis to save')),
      );
    }
  }
}
