import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart' as login;
import 'package:audioplayers/audioplayers.dart';

class UploadFileScreen extends StatefulWidget {
  final String serverUrl;

  const UploadFileScreen({super.key, required this.serverUrl});

  @override
  State<UploadFileScreen> createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  File? _selectedFile;
  bool _isAnalyzing = false;
  bool _isPlaying = false;
  bool _isLoadingAudio = false;
  String _status = 'Select a .wav audio file to analyze';
  Map<String, double> _emotionResults = {};
  String? _error;

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Set up audio player completion listener
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _status = 'Playback finished';
          _position = Duration.zero;
        });
      }
    });

    // Listen for position changes
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen for duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String fileName = file.path.toLowerCase();

        // Check if it's a wav file
        if (!fileName.endsWith('.wav')) {
          if (mounted) {
            setState(() {
              _error = 'Please select a .wav audio file.';
              _status = 'Only .wav files are supported.';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _selectedFile = file;
            _emotionResults = {};
            _isAnalyzing = false;
            _error = null;
            _status = 'File selected: ${file.path.split('/').last}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error picking file: $e';
          _status = 'Failed to select file.';
        });
      }
    }
  }

  Future<void> _analyzeFile() async {
    if (_selectedFile == null) return;

    if (mounted) {
      setState(() {
        _isAnalyzing = true;
        _status = 'Analyzing audio file...';
        _emotionResults = {};
      });
    }

    try {
      // First check if the server is available
      try {
        final healthResponse = await http
            .get(Uri.parse('${widget.serverUrl}/health'))
            .timeout(const Duration(seconds: 5));

        if (healthResponse.statusCode != 200) {
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _status = 'Server not available. Please try again later.';
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _status = 'Server connection failed: $e';
          });
        }
        return;
      }

      // Create multipart request
      final apiUrl = '${widget.serverUrl}/analyze_emotion';
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add the file
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          _selectedFile!.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      // Update status
      if (mounted) {
        setState(() {
          _status = 'Sending file to server...';
        });
      }

      // Send the request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException(
              'Connection timed out. The server might be busy or the file might be too large.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> responseData = json.decode(response.body);

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
          if (mounted) {
            setState(() {
              _isAnalyzing = false;
              _status = 'No valid emotion data found in the response';
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _emotionResults = emotions;
            _isAnalyzing = false;
            _status = 'Analysis complete';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAnalyzing = false;
            _status = 'Server error: ${response.statusCode} ${response.body}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _status = 'Error analyzing file: $e';
        });
      }
    }
  }

  String _getPrimaryEmotion() {
    if (_emotionResults.isEmpty) return 'Unknown';
    return _emotionResults.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  void _clearSelection() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
    }

    if (mounted) {
      setState(() {
        _selectedFile = null;
        _emotionResults = {};
        _isAnalyzing = false;
        _isPlaying = false;
        _isLoadingAudio = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _error = null;
      });
    }
  }

  Future<void> _playAudio() async {
    if (_selectedFile == null) return;

    try {
      if (_isPlaying) {
        // Stop playback if already playing
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _status = 'Playback stopped';
          });
        }
      } else {
        // Show loading state
        if (mounted) {
          setState(() {
            _isLoadingAudio = true;
            _status = 'Loading audio...';
          });
        }

        // Start playback
        final source = DeviceFileSource(_selectedFile!.path);
        await _audioPlayer.play(source);

        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoadingAudio = false;
            _status = 'Playing audio...';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error playing audio: $e';
          _isPlaying = false;
          _isLoadingAudio = false;
        });
      }
    }
  }

  // Format duration as mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Upload Audio File',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: login.AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _isAnalyzing ? Colors.blue.shade50 : Colors.grey.shade50,
              child: Row(
                children: [
                  Icon(
                    _isAnalyzing ? Icons.hourglass_top : Icons.info_outline,
                    color: _isAnalyzing ? Colors.blue : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        color:
                            _isAnalyzing ? Colors.blue : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error Message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // File Upload Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_selectedFile == null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: InkWell(
                        onTap: _pickFile,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 60,
                              color: login.AppColors.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap to select a .wav file',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Only 16-bit PCM .wav audio files are supported',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'If you have trouble with file selection, try renaming the file to ensure it ends with .wav',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_selectedFile != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.audio_file,
                                  color: login.AppColors.primary, size: 40),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFile!.path.split('/').last,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    FutureBuilder<int>(
                                      future: _selectedFile!.length(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          final kb = snapshot.data! / 1024;
                                          return Text(
                                            '${kb.toStringAsFixed(2)} KB',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          );
                                        }
                                        return const Text('Loading size...');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: _isLoadingAudio
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.blue,
                                        ),
                                      )
                                    : Icon(
                                        _isPlaying
                                            ? Icons.stop
                                            : Icons.play_arrow,
                                        color: _isPlaying
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                onPressed: _isLoadingAudio ? null : _playAudio,
                                tooltip: _isPlaying ? 'Stop' : 'Play',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: _clearSelection,
                              ),
                            ],
                          ),
                          if (_isPlaying)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  Slider(
                                    value: _position.inSeconds.toDouble(),
                                    min: 0,
                                    max: _duration.inSeconds.toDouble() > 0
                                        ? _duration.inSeconds.toDouble()
                                        : 1,
                                    onChanged: (value) async {
                                      final position =
                                          Duration(seconds: value.toInt());
                                      await _audioPlayer.seek(position);
                                    },
                                    activeColor: login.AppColors.primary,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(_position)),
                                        Text(_formatDuration(_duration)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Analyze Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAnalyzing
                          ? null
                          : (_selectedFile != null ? _analyzeFile : _pickFile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: login.AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isAnalyzing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Analyzing...'),
                              ],
                            )
                          : Text(_selectedFile != null
                              ? 'Analyze Audio'
                              : 'Select File'),
                    ),
                  ),
                ],
              ),
            ),

            // Results
            if (_emotionResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Analysis Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Primary emotion
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: login.AppColors.getEmotionColor(
                                  _getPrimaryEmotion())
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
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
                                color: login.AppColors.getEmotionColor(
                                    _getPrimaryEmotion()),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${_emotionResults[_getPrimaryEmotion()]?.toStringAsFixed(1) ?? "0"}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: login.AppColors.getEmotionColor(
                                    _getPrimaryEmotion()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // All emotions
                      ...List.generate(
                        _emotionResults.length,
                        (index) {
                          final emotion = _emotionResults.keys.elementAt(index);
                          final value = _emotionResults.values.elementAt(index);
                          final color =
                              login.AppColors.getEmotionColor(emotion);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      login.AppColors.getFullEmotionName(
                                          emotion),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      '${value.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: value / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
