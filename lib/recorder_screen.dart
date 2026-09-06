import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'login_screen.dart' as login;
import 'history_screen.dart';

class RecorderScreen extends StatefulWidget {
  final String serverUrl;

  const RecorderScreen({super.key, required this.serverUrl});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  bool _isAnalyzing = false;
  String? _recordPath;
  String? _currentlyPlayingPath;
  String _status = 'Tap the mic to start recording';
  int _recordingDuration = 5; // Default recording duration in seconds
  int _recordingMaxDuration = 30; // Maximum recording duration
  late String _serverUrl;

  // Animation controller for the record button
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Emotion results
  Map<String, double> _emotionResults = {};

  // Stats for recordings
  int _recordingsCount = 0;
  int _analysesCount = 0;

  // Audio amplitude values for the waveform display
  List<double> _amplitudes = [];
  Timer? _amplitudeTimer;

  @override
  void initState() {
    super.initState();
    // Set server URL from widget parameter or use default
    _serverUrl = widget.serverUrl;

    // Debug server URL
    print('RecorderScreen initialized with server URL: $_serverUrl');

    // Validate server URL format
    if (_serverUrl.isEmpty) {
      _status = 'ERROR: Server URL is empty. Please check settings.';
      print('SERVER URL ERROR: Empty URL');
    } else if (!_serverUrl.startsWith('http')) {
      _status =
          'ERROR: Invalid server URL. Must start with http:// or https://';
      print('SERVER URL ERROR: Invalid URL format: $_serverUrl');
    } else {
      _status = 'Ready to record. Server: $_serverUrl';
    }

    _requestPermission();
    _loadRecordingStats();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Set up audio player completion listener
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
          _status = 'Playback finished';
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _amplitudeTimer?.cancel();
    super.dispose();
  }

  // Method to completely reset the recorder state
  void _resetRecorderState() {
    if (_isRecording) {
      _audioRecorder.stop();
    }

    if (_isPlaying) {
      _audioPlayer.stop();
    }

    _amplitudeTimer?.cancel();
    _isRecording = false;
    _isPaused = false;
    _isPlaying = false;
    _isAnalyzing = false;
    _recordPath = null;
    _currentlyPlayingPath = null;
    _emotionResults = {};
    _amplitudes = [];

    if (mounted) {
      setState(() {
        _status = 'Recorder state reset';
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _status = 'Microphone permission is required!';
        });
      }
    }
  }

  Future<void> _startRecording() async {
    // Cancel any ongoing operations
    if (_isAnalyzing || _isPlaying) {
      print('Canceling ongoing operations before starting new recording');
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _isPlaying = false;
        });
      }
    }

    try {
      // Always create a new file for each recording
      final directory = await getApplicationDocumentsDirectory();
      await Directory('${directory.path}/recordings').create(recursive: true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recording_$timestamp.wav';
      final newPath = '${directory.path}/recordings/$fileName';

      print('Starting new recording at path: $newPath');
      _recordPath = newPath;

      // Check microphone permission
      if (await Permission.microphone.isGranted) {
        // Get ready to record audio with better settings
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
        }

        // Configure with settings matching the Python code
        final config = RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 256000,
          sampleRate: 16000,
        );

        // Clear previous results
        _emotionResults = {};
        _amplitudes = [];

        // Start recording
        await _audioRecorder.start(config, path: _recordPath!);

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _status = 'Recording... Speak now ($fileName)';
        });

        // Start the animation
        _animationController.repeat(reverse: true);

        // Start monitoring amplitude
        _monitorAmplitude();

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

  void _monitorAmplitude() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isRecording || _isPaused) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _audioRecorder.getAmplitude();
        final maxAmplitude = amplitude.current ?? 0.0;

        // Normalize and add to list (values typically between 0-1)
        if (mounted) {
          setState(() {
            _amplitudes.add(maxAmplitude);
            // Keep only the most recent 100 values
            if (_amplitudes.length > 100) {
              _amplitudes.removeAt(0);
            }
          });
        }
      } catch (e) {
        print('Error getting amplitude: $e');
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _amplitudeTimer?.cancel();
      _animationController.stop();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _status = 'Recording stopped';
        });
      }

      if (path != null) {
        // Check if file exists and has valid size
        final file = File(path);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('File exists with size: ${fileSize} bytes');

          if (fileSize > 1000) {
            // Check if file is not too small (empty)
            if (mounted) {
              setState(() {
                _recordPath = path;
                _status =
                    'Recording saved: ${(fileSize / 1024).toStringAsFixed(2)} KB';
              });
            }

            // Automatically analyze the audio after successfully recording
            await _analyzeAudio();
          } else {
            if (mounted) {
              setState(() {
                _status =
                    'Warning: Recording file is too small. Please try speaking louder';
              });
            }
          }
        } else {
          print('Error: File does not exist at path: $path');
          if (mounted) {
            setState(() {
              _status = 'Error: Recorded file not found';
            });
          }
        }
      } else {
        print('Error: No path returned from recorder.stop()');
        if (mounted) {
          setState(() {
            _status = 'Error: No recording path returned';
          });
        }
      }
    } catch (e) {
      print('Error in _stopRecording: $e');
      if (mounted) {
        setState(() {
          _status = 'Error stopping recording: $e';
        });
      }
    }
  }

  Future<void> _pauseRecording() async {
    _animationController.stop();
    try {
      await _audioRecorder.pause();
      if (mounted) {
        setState(() {
          _isPaused = true;
          _status = 'Recording paused';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error pausing recording: $e';
        });
      }
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      if (mounted) {
        setState(() {
          _isPaused = false;
          _status = 'Recording resumed';
        });
      }

      // Resume the animation
      _animationController.repeat(reverse: true);

      // Resume monitoring amplitude
      _monitorAmplitude();
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error resuming recording: $e';
        });
      }
    }
  }

  Future<void> _playRecording() async {
    if (_recordPath == null) return;

    try {
      // First stop any currently playing audio
      if (_isPlaying) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingPath = null;
            _status = 'Playback stopped';
          });
        }
        return;
      }

      // Play the audio file
      final source = DeviceFileSource(_recordPath!);
      await _audioPlayer.play(source);

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = _recordPath;
          _status = 'Playing recording...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
          _status = 'Error playing recording: $e';
        });
      }
    }
  }

  Future<void> _analyzeAudio() async {
    try {
      if (_recordPath == null) {
        if (mounted) {
          setState(() {
            _status = 'No recording to analyze';
          });
        }
        return;
      }

      // Set analyzing state
      if (mounted) {
        setState(() {
          _isAnalyzing = true;
          _status = 'Connecting to server...';
          _emotionResults = {}; // Clear previous results
        });
      }

      final file = File(_recordPath!);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _status = 'Recording file not found: $_recordPath';
          });
        }
        return;
      }

      // Get file size for better status updates
      final fileSize = await file.length();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);

      // Debug server URL
      print('Using server URL: $_serverUrl');

      // Check if server is available
      try {
        print('Checking server health at: $_serverUrl/health');
        final healthResponse = await http
            .get(Uri.parse('$_serverUrl/health'))
            .timeout(const Duration(seconds: 5));

        print(
            'Health check response: ${healthResponse.statusCode} ${healthResponse.body}');

        if (healthResponse.statusCode != 200) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _status =
                  'Server health check failed with code ${healthResponse.statusCode}. Server may be starting up, please try again in a moment.';
            });
          }
          return;
        }
      } catch (e) {
        print('Error checking server health: $e');
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _status = 'Server connection error: $e';
          });
        }
        return;
      }

      // Show the URL being used to help debug
      if (mounted) {
        setState(() {
          _status =
              'Sending file (${fileSizeKB} KB) to $_serverUrl/analyze_emotion';
        });
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_serverUrl/analyze_emotion'),
      );

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          _recordPath!,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      print('Sending file to server: ${_recordPath!}');

      // Send the request
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );

      final response = await http.Response.fromStream(streamedResponse);
      print('Server response status: ${response.statusCode}');
      print('Server response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          print('Successfully parsed response JSON: $responseData');

          // Extract emotion results
          Map<String, dynamic>? emotionsData = responseData['emotions'];

          if (emotionsData == null) {
            // Fall back to the whole response if 'emotions' key is not found
            print('No emotions key found, using whole response');
            emotionsData = responseData;
          }

          // Convert to the expected format
          final Map<String, double> emotions = {};
          emotionsData?.forEach((key, value) {
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

          print('Parsed emotions: $emotions');

          if (emotions.isEmpty) {
            if (mounted) {
              setState(() {
                _isAnalyzing = false;
                _status =
                    'No valid emotion data found in the response. Check server logs.';
              });
            }
            return;
          }

          // Save analysis results
          await _saveAnalysisResults(emotions, null);

          if (mounted) {
            setState(() {
              _emotionResults = emotions;
              _isAnalyzing = false;
              _status = 'Analysis complete! Results displayed below.';

              // Refresh stats after successful analysis
              _loadRecordingStats();
            });
          }
        } catch (e) {
          print('Error parsing response: $e');
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _status = 'Error parsing response: $e';
            });
          }
        }
      } else {
        print('Server error: ${response.statusCode} ${response.body}');
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _status =
                'Server error: ${response.statusCode} ${response.reasonPhrase}';
          });
        }
      }
    } catch (e) {
      print('Error in _analyzeAudio: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _status = 'Error analyzing audio: $e';
        });
      }
    }
  }

  // Save analysis results locally (only metadata, not the audio file)
  Future<void> _saveAnalysisResults(
      Map<String, double> emotions, String? serverFilePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final analysesDir = Directory('${directory.path}/analyses');

      if (!await analysesDir.exists()) {
        await analysesDir.create(recursive: true);
      }

      // Generate a unique file name for the analysis
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final analysisFile = File('${analysesDir.path}/analysis_$timestamp.json');

      // Create analysis data with metadata
      final analysisData = {
        'timestamp': timestamp,
        'emotions': emotions,
        'serverFilePath':
            serverFilePath, // Store the server path instead of local path
        'name': 'Analysis $timestamp',
      };

      // Save the analysis data
      await analysisFile.writeAsString(json.encode(analysisData));
      print('Analysis saved to ${analysisFile.path}');
    } catch (e) {
      print('Error saving analysis: $e');
    }
  }

  // Method to update server URL from outside
  void updateServerUrl(String url) {
    setState(() {
      _serverUrl = url;
      _status = 'Server URL updated to: $_serverUrl';
    });
  }

  @override
  void didUpdateWidget(RecorderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update server URL if it changed
    if (widget.serverUrl != oldWidget.serverUrl) {
      _serverUrl = widget.serverUrl;
      _status = 'Server URL updated to: $_serverUrl';
      print('RecorderScreen updated with new server URL: $_serverUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice Recorder',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: login.AppColors.primary,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: true,
        
         
        actions: [
          // Add reset button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _resetRecorderState,
            tooltip: 'Reset Recorder',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Server URL info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.computer, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Server: $_serverUrl',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Current recording file info
            if (_recordPath != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File: ${_recordPath!.split('/').last}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Waveform and Status Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    login.AppColors.primary,
                    login.AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Waveform Visualization
                  Container(
                    width: double.infinity,
                    height: 120,
                    child: Center(
                      child: _isRecording
                          ? VoiceVisualizerWidget(
                              amplitudes: _amplitudes,
                              color: Colors.white,
                              animating: _isRecording && !_isPaused,
                            )
                          : CircularWaveVisualizer(
                              baseColor: Colors.white.withOpacity(0.3),
                              waveColor: Colors.white,
                              showAnimation: _isPlaying,
                            ),
                    ),
                  ),

                  // Recording Animation
                  SizedBox(
                    height: 30,
                    child: _isRecording
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRecordingDot(),
                              const SizedBox(width: 8),
                              Text(
                                "RECORDING",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : _isAnalyzing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "ANALYZING",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                  ),

                  // Status Text
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Duration Slider
                  if (!_isRecording && !_isAnalyzing)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          const Text(
                            'Duration:',
                            style: TextStyle(color: Colors.white),
                          ),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 30,
                              divisions: 29,
                              value: _recordingDuration.toDouble(),
                              activeColor: Colors.white,
                              inactiveColor: Colors.white.withOpacity(0.3),
                              onChanged: (value) {
                                setState(() {
                                  _recordingDuration = value.toInt();
                                });
                              },
                            ),
                          ),
                          Text(
                            '$_recordingDuration sec',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Recording Controls
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play Button
                  if (!_isRecording && _recordPath != null)
                    _buildControlButton(
                      icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                      label: _isPlaying ? 'Stop' : 'Play',
                      color: Colors.blue,
                      onPressed: _playRecording,
                    ),

                  // Record/Stop Button
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording ? _scaleAnimation.value : 1.0,
                        child: _buildRecordButton(),
                      );
                    },
                  ),

                  // Pause/Resume Button
                  if (_isRecording)
                    _buildControlButton(
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      label: _isPaused ? 'Resume' : 'Pause',
                      color: Colors.orange,
                      onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                    ),

                  // Analyze Button (when not recording but has a recording)
                  if (!_isRecording &&
                      _recordPath != null &&
                      _emotionResults.isEmpty)
                    _buildControlButton(
                      icon: Icons.analytics,
                      label: 'Analyze',
                      color: Colors.green,
                      onPressed: _analyzeAudio,
                    ),
                ],
              ),
            ),

            // Emotion Results Section
            if (_emotionResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildEmotionResults(),
              ),

            // Tips and Info Section
            if (_emotionResults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Get Started',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: login.AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      icon: Icons.record_voice_over,
                      title: 'Record Your Voice',
                      description:
                          'Tap the microphone button and speak clearly for $_recordingDuration seconds.',
                      color: login.AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.graphic_eq,
                      title: 'Analyze Emotions',
                      description:
                          'After recording, your voice will be analyzed for emotional patterns.',
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.tips_and_updates,
                      title: 'Pro Tip',
                      description:
                          'For best results, record in a quiet environment and speak naturally.',
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Voice data is processed securely. Your privacy is important to us.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : login.AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? Colors.red : login.AppColors.primary)
                  .withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionResults() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.emoji_emotions, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Emotion Analysis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                // Dominant emotion indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(_getPrimaryEmotion())
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
                        login.AppColors.getFullEmotionName(
                            _getPrimaryEmotion()),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getEmotionColor(_getPrimaryEmotion()),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_emotionResults[_getPrimaryEmotion()]?.toStringAsFixed(1) ?? "0"}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _getEmotionColor(_getPrimaryEmotion()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Emotion bars
                Container(
                  height: 180,
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _emotionResults.length,
                    itemBuilder: (context, index) {
                      final emotion = _emotionResults.keys.elementAt(index);
                      final value = _emotionResults.values.elementAt(index);
                      final fullName =
                          login.AppColors.getFullEmotionName(emotion);
                      final color = _getEmotionColor(emotion);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                // Foreground
                                Container(
                                  height: 12,
                                  width:
                                      (MediaQuery.of(context).size.width - 64) *
                                          (value / 100),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
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
          ],
        ),
      ),
    );
  }

  String _getPrimaryEmotion() {
    if (_emotionResults.isEmpty) return 'Unknown';
    return _emotionResults.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Color _getEmotionColor(String emotion) {
    return login.AppColors.getEmotionColor(emotion);
  }

  // Add this new method to create the pulsing recording dot
  Widget _buildRecordingDot() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(_scaleAnimation.value * 0.8),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadRecordingStats() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      // Check for recordings
      final recordingsDir = Directory('${directory.path}/recordings');
      if (await recordingsDir.exists()) {
        final files = await recordingsDir
            .list()
            .where((file) => file.path.toLowerCase().endsWith('.wav'))
            .toList();

        setState(() {
          _recordingsCount = files.length;
        });
      }

      // Check for analyses
      final analysesDir = Directory('${directory.path}/analyses');
      if (await analysesDir.exists()) {
        final files = await analysesDir
            .list()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList();

        setState(() {
          _analysesCount = files.length;
        });
      }
    } catch (e) {
      print('Error loading recording stats: $e');
    }
  }
}

class CircularWaveVisualizer extends StatefulWidget {
  final Color baseColor;
  final Color waveColor;
  final bool showAnimation;

  const CircularWaveVisualizer({
    Key? key,
    required this.baseColor,
    required this.waveColor,
    this.showAnimation = false,
  }) : super(key: key);

  @override
  State<CircularWaveVisualizer> createState() => _CircularWaveVisualizerState();
}

class _CircularWaveVisualizerState extends State<CircularWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.showAnimation) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showAnimation != oldWidget.showAnimation) {
      if (widget.showAnimation) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: CircularWavePainter(
            animation: _animationController.value,
            baseColor: widget.baseColor,
            waveColor: widget.waveColor,
            showAnimation: widget.showAnimation,
          ),
          child: SizedBox(
            width: 150,
            height: 150,
            child: Center(
              child: Icon(
                widget.showAnimation ? Icons.volume_up : Icons.mic,
                color: widget.waveColor,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CircularWavePainter extends CustomPainter {
  final double animation;
  final Color baseColor;
  final Color waveColor;
  final bool showAnimation;

  CircularWavePainter({
    required this.animation,
    required this.baseColor,
    required this.waveColor,
    required this.showAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw the base circle
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.7, basePaint);

    // Draw wave circles
    final wavePaint = Paint()
      ..color =
          waveColor.withOpacity(showAnimation ? 0.5 - animation * 0.45 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = showAnimation ? 3.0 : 2.0;

    if (showAnimation) {
      for (int i = 0; i < 3; i++) {
        double wavePhase = (animation + (i * 0.3)) % 1.0;
        double waveRadius = radius * 0.7 + (wavePhase * radius * 0.7);
        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    } else {
      // Static waves when not playing
      canvas.drawCircle(center, radius * 0.8, wavePaint..strokeWidth = 1.5);
      canvas.drawCircle(center, radius * 0.9, wavePaint..strokeWidth = 1.0);
      canvas.drawCircle(center, radius, wavePaint..strokeWidth = 0.5);
    }
  }

  @override
  bool shouldRepaint(CircularWavePainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.showAnimation != showAnimation;
  }
}

class VoiceVisualizerWidget extends StatefulWidget {
  final List<double> amplitudes;
  final Color color;
  final bool animating;

  const VoiceVisualizerWidget({
    Key? key,
    required this.amplitudes,
    required this.color,
    this.animating = false,
  }) : super(key: key);

  @override
  State<VoiceVisualizerWidget> createState() => _VoiceVisualizerWidgetState();
}

class _VoiceVisualizerWidgetState extends State<VoiceVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.animating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceVisualizerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating != oldWidget.animating) {
      if (widget.animating) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: VoiceCirclePainter(
            amplitudes: widget.amplitudes,
            color: widget.color,
            animationValue: _controller.value,
          ),
          size: const Size(150, 150),
        );
      },
    );
  }
}

class VoiceCirclePainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final double animationValue;

  VoiceCirclePainter({
    required this.amplitudes,
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.3;

    // Base circle
    final basePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, baseRadius, basePaint);

    // Mic icon
    const iconSize = 30.0;
    final iconRect = Rect.fromCenter(
      center: center,
      width: iconSize,
      height: iconSize,
    );

    final iconPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(iconRect, Radius.circular(8)),
      iconPaint,
    );

    // Generate points for dynamic visualization
    final points = <Offset>[];
    final numPoints = 40; // Number of points around the circle

    // We'll create a smooth wave effect that responds to the amplitudes
    // but looks more professional than just lines

    // Get average amplitude for a smoother effect
    double avgAmplitude = 0.3;
    if (amplitudes.isNotEmpty) {
      // Use recent amplitudes and apply more weight to recent ones
      final recentAmplitudes = amplitudes.length > 10
          ? amplitudes.sublist(amplitudes.length - 10)
          : amplitudes;

      if (recentAmplitudes.isNotEmpty) {
        avgAmplitude =
            recentAmplitudes.reduce((a, b) => a + b) / recentAmplitudes.length;
        // Scale and clamp for better visual
        avgAmplitude = (avgAmplitude * 3.0).clamp(0.15, 0.8);
      }
    }

    // Create wave effect
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * 3.14159; // Convert to radians

      // Create dynamic radius with wave effect
      double dynamicFactor = avgAmplitude;

      // Add sine wave variations with animation
      final waveFactor1 = sin(angle * 6 + animationValue * 2 * 3.14159) * 0.15;
      final waveFactor2 = sin(angle * 8 - animationValue * 2 * 3.14159) * 0.1;
      final waveFactor3 = cos(angle * 4 + animationValue * 4 * 3.14159) * 0.1;

      final radiusFactor =
          dynamicFactor * (1.0 + waveFactor1 + waveFactor2 + waveFactor3);
      final radius = baseRadius * (1.0 + radiusFactor);

      // Calculate point position
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      points.add(Offset(x, y));
    }

    // Close the path
    if (points.isNotEmpty) {
      points.add(points.first);
    }

    // Draw the wave effect
    final path = Path()..addPolygon(points, false);

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, wavePaint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant VoiceCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.amplitudes != amplitudes;
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter(this.amplitudes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final width = size.width;
    final barWidth = width / amplitudes.length;

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * barWidth;
      final barHeight = amplitudes[i] * size.height * 0.8;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
