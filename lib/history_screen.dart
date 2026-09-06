import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'login_screen.dart' as login;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // Import for AppColors class

class HistoryScreen extends StatefulWidget {
  final String? serverUrl;

  const HistoryScreen({super.key, this.serverUrl});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<FileSystemEntity> _recordings = [];
  List<HistoryItem> _historyItems = [];
  List<ServerRecording> _serverRecordings = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  bool _isLoadingServerData = false;
  bool _isAnalyzing = false;
  String? _serverUrl;
  String? _errorMessage;

  int _currentTab =
      0; // 0 for recordings, 1 for analyses, 2 for server recordings
  late TabController _tabController;

  // Map to store analysis results with recording path as key
  final Map<String, Map<String, double>> _analysisResults = {};
  // Track which recording's analysis is expanded
  String? _expandedRecordingPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });

    // Set server URL from widget parameter
    _serverUrl = widget.serverUrl;

    // Force a delay to ensure recordings are detected after saving
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadRecordings();
        _loadAnalyses();
        if (_serverUrl != null) {
          _loadServerRecordings();
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecordings();
      _loadAnalyses();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      debugPrint('Looking for recordings in: ${recordingsDir.path}');

      if (await recordingsDir.exists()) {
        debugPrint('Recordings directory exists');

        // For Windows, we need to use a different approach to list files
        List<FileSystemEntity> files = [];
        if (Platform.isWindows) {
          try {
            final dir = Directory(recordingsDir.path);
            files = await dir.list(recursive: false).toList();
            debugPrint('Windows directory listing found ${files.length} items');
          } catch (e) {
            debugPrint('Error listing directory on Windows: $e');
          }
        } else {
          files = await recordingsDir.list().toList();
        }

        debugPrint('Found ${files.length} files in recordings directory');

        // More detailed debugging for file detection
        for (var file in files) {
          final path = file.path;
          final extension =
              path.substring(path.lastIndexOf('.') + 1).toLowerCase();
          debugPrint(
              'File: $path, Extension: $extension, isWav: ${extension == 'wav'}');
        }

        final wavFiles = files.where((file) {
          final path = file.path.toLowerCase();
          return path.endsWith('.wav');
        }).toList();

        debugPrint('Found ${wavFiles.length} WAV files');

        // Log file paths for debugging
        for (var file in wavFiles) {
          debugPrint('WAV file: ${file.path}');
        }

        if (mounted) {
          setState(() {
            _recordings = wavFiles
              ..sort((a, b) =>
                  b.statSync().modified.compareTo(a.statSync().modified));
          });
        }

        // If still empty, try a more aggressive approach
        if (_recordings.isEmpty) {
          debugPrint('No recordings found, trying recursive search...');
          _findWavFilesRecursively(directory.path);
        }
      } else {
        debugPrint('Recordings directory does not exist. Creating it...');
        await recordingsDir.create(recursive: true);
        if (mounted) {
          setState(() {
            _recordings = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading recordings: $e');
      if (mounted) {
        setState(() {
          _recordings = [];
        });
      }
    }
  }

  Future<void> _findWavFilesRecursively(String rootPath) async {
    try {
      final root = Directory(rootPath);
      final entities = await root.list(recursive: true).toList();

      final wavFiles = entities
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.wav'))
          .toList();

      debugPrint('Recursive search found ${wavFiles.length} WAV files');

      for (var file in wavFiles) {
        debugPrint('Recursive WAV file: ${file.path}');
      }

      if (wavFiles.isNotEmpty) {
        if (mounted) {
          setState(() {
            _recordings = wavFiles
              ..sort((a, b) =>
                  b.statSync().modified.compareTo(a.statSync().modified));
          });
        }
      }
    } catch (e) {
      debugPrint('Error in recursive search: $e');
    }
  }

  Future<void> _loadAnalyses() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final analysesDir = Directory('${directory.path}/analyses');

      if (await analysesDir.exists()) {
        final files = await analysesDir
            .list()
            .where((file) => file.path.endsWith('.json'))
            .toList();

        List<HistoryItem> historyItems = [];

        for (var file in files) {
          try {
            final content = await File(file.path).readAsString();
            final data = json.decode(content);

            // Add the file path to the data for reference
            data['filePath'] = file.path;

            historyItems.add(HistoryItem.fromJson(data, file.path));
          } catch (e) {
            debugPrint('Error parsing analysis file: $e');
          }
        }

        // Sort by timestamp, newest first
        historyItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (mounted) {
          setState(() {
            _historyItems = historyItems;
          });
        }
      } else {
        debugPrint('Analyses directory does not exist yet');
        if (mounted) {
          setState(() {
            _historyItems = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading analyses: $e');
      if (mounted) {
        setState(() {
          _historyItems = [];
        });
      }
    }
  }

  Future<void> _playRecording(String path) async {
    try {
      // Stop any currently playing audio
      if (_isPlaying) {
        await _audioPlayer.stop();
      }

      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingPath = path;
        });
      }

      // Check if this is a server path or local path
      if (path.startsWith('http')) {
        // Stream from URL
        await _audioPlayer.play(UrlSource(path));
      } else if (path.startsWith('/')) {
        // Play local file
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        // Try to play file anyway
        await _audioPlayer.play(DeviceFileSource(path));
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');

      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPath = null;
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing recording: $e')),
        );
      }
    }
  }

  // Check if server file exists and stream it if possible
  Future<void> _streamFromServer(HistoryItem item, String serverUrl) async {
    if (item.serverFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No server file path available')),
      );
      return;
    }

    try {
      // Assume we need to construct a URL to stream from server
      final serverFilename = item.serverFilePath!.split('/').last;
      final streamUrl = '$serverUrl/stream/$serverFilename';

      debugPrint('Attempting to stream from: $streamUrl');

      // Check if the server file is accessible
      final response = await http.head(Uri.parse(streamUrl));

      if (response.statusCode == 200) {
        // File exists on server, play it
        _playRecording(streamUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Server file not available: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error streaming from server: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error streaming from server: $e')),
      );
    }
  }

  Future<void> _deleteRecording(FileSystemEntity file) async {
    try {
      // Stop playback if deleting the currently playing file
      if (_currentlyPlayingPath == file.path) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingPath = null;
          });
        }
      }

      // Delete the file
      await file.delete();

      // Remove any stored analysis results
      if (mounted) {
        setState(() {
          _analysisResults.remove(file.path);
          if (_expandedRecordingPath == file.path) {
            _expandedRecordingPath = null;
          }
        });
      }

      // Refresh the list
      _loadRecordings();
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  Future<void> _deleteAnalysis(HistoryItem item) async {
    try {
      // Delete the analysis file
      final file = File(item.localFilePath);
      await file.delete();

      // Refresh the list
      _loadAnalyses();
    } catch (e) {
      debugPrint('Error deleting analysis: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final fileDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (fileDate == today) {
      return 'Today, ${DateFormat.jm().format(dateTime)}';
    } else if (fileDate == yesterday) {
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else {
      return DateFormat('MMM d, yyyy - h:mm a').format(dateTime);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<Duration?> _getAudioDuration(String path) async {
    try {
      final file = File(path);
      final fileLength = await file.length();
      // Rough estimate for WAV files at 16-bit, 16kHz, mono
      final durationInSeconds = fileLength / (16000 * 2);
      return Duration(seconds: durationInSeconds.round());
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadServerRecordings() async {
    if (_serverUrl == null) {
      setState(() {
        _errorMessage = 'Server URL not configured';
      });
      return;
    }

    setState(() {
      _isLoadingServerData = true;
      _errorMessage = null;
    });

    try {
      final recordingsUrl = '$_serverUrl/recordings';
      debugPrint('Fetching recordings from: $recordingsUrl');

      final response = await http
          .get(
            Uri.parse(recordingsUrl),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> recordingsList = data['recordings'] ?? [];

        List<ServerRecording> recordings = recordingsList.map((item) {
          return ServerRecording.fromJson(item, _serverUrl!);
        }).toList();

        if (mounted) {
          setState(() {
            _serverRecordings = recordings;
            _isLoadingServerData = false;
          });
        }

        debugPrint('Loaded ${recordings.length} server recordings');
      } else {
        debugPrint('Failed to load server recordings: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load recordings: ${response.statusCode}';
            _isLoadingServerData = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading server recordings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error: $e';
          _isLoadingServerData = false;
        });
      }
    }
  }

  Future<void> _analyzeRecording(File file) async {
    if (_serverUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL not configured')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      // Clear any previous expanded state
      _expandedRecordingPath = null;
    });

    try {
      // Check server health first
      final healthResponse = await http
          .get(Uri.parse('$_serverUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (healthResponse.statusCode != 200) {
        setState(() {
          _isAnalyzing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Server health check failed: ${healthResponse.statusCode}')),
        );
        return;
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
          file.path,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyzing recording...')),
      );

      // Send the request
      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract emotion results
        Map<String, dynamic>? emotionsData = data['emotions'];

        if (emotionsData != null) {
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

          // Store results
          if (mounted) {
            setState(() {
              _analysisResults[file.path] = emotions;
              _expandedRecordingPath = file.path; // Auto-expand this recording
            });
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Analysis complete! Showing results below'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No emotion data in response')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recording History',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: login.AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent back button
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecordings,
            tooltip: 'Refresh Recordings',
          ),
          if (_recordings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _showDeleteAllDialog,
              tooltip: 'Delete All Recordings',
            ),
        ],
      ),
      body: _recordings.isEmpty
          ? _buildEmptyState('No recordings yet')
          : _buildRecordingsList(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _currentTab == 0
                ? Icons.music_note_outlined
                : _currentTab == 1
                    ? Icons.bar_chart
                    : Icons.cloud,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentTab == 0
                ? 'Your recordings will appear here'
                : _currentTab == 1
                    ? 'Save analyses of your recordings to view them here'
                    : 'Server recordings will appear here',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            login.AppColors.primary.withOpacity(0.05),
            Colors.white,
          ],
        ),
      ),
      child: ListView.builder(
        itemCount: _recordings.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final file = _recordings[index];
          final fileName = file.path.split('/').last;
          final fileStats = file.statSync();
          final isPlaying = _currentlyPlayingPath == file.path && _isPlaying;
          final hasAnalysisResults = _analysisResults.containsKey(file.path);
          final isExpanded = _expandedRecordingPath == file.path;

          return FutureBuilder<Duration?>(
            future: _getAudioDuration(file.path),
            builder: (context, snapshot) {
              final duration = snapshot.data;
              final durationText =
                  duration != null ? _formatDuration(duration) : '00:00';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Recording info
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: login.AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: login.AppColors.primary,
                              size: 36,
                            ),
                          ),
                          if (hasAnalysisResults)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        fileName
                            .replaceAll('recording_', '')
                            .replaceAll('.wav', ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(fileStats.modified),
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.timer,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                durationText,
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          if (hasAnalysisResults) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getEmotionColor(_getPrimaryEmotion(
                                            _analysisResults[file.path]!))
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    login.AppColors.getFullEmotionName(
                                        _getPrimaryEmotion(
                                            _analysisResults[file.path]!)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getEmotionColor(
                                          _getPrimaryEmotion(
                                              _analysisResults[file.path]!)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (hasAnalysisResults)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _expandedRecordingPath =
                                            isExpanded ? null : file.path;
                                      });
                                    },
                                    child: Text(
                                      isExpanded
                                          ? 'Hide details'
                                          : 'Show details',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: login.AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red.shade300,
                        onPressed: () => showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Recording'),
                            content: const Text(
                                'Are you sure you want to delete this recording?'),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              TextButton(
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _deleteRecording(file);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      onTap: () => _playRecording(file.path),
                    ),

                    // Analysis results section (if expanded)
                    if (isExpanded && hasAnalysisResults)
                      _buildAnalysisResultsSection(file.path),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon:
                                const Icon(Icons.analytics_outlined, size: 16),
                            label:
                                Text(_isAnalyzing ? 'Analyzing...' : 'Analyze'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasAnalysisResults
                                  ? Colors.grey.shade200
                                  : login.AppColors.primary,
                              foregroundColor: hasAnalysisResults
                                  ? Colors.black54
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: (_isAnalyzing ||
                                    (hasAnalysisResults && !isExpanded))
                                ? null
                                : () => hasAnalysisResults
                                    ? setState(() =>
                                        _expandedRecordingPath = file.path)
                                    : _analyzeRecording(File(file.path)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnalysisResultsSection(String filePath) {
    final emotions = _analysisResults[filePath]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emotion Analysis',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              // Dominant emotion indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _getEmotionColor(_getPrimaryEmotion(emotions))
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
                          _getPrimaryEmotion(emotions)),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getEmotionColor(_getPrimaryEmotion(emotions)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${emotions[_getPrimaryEmotion(emotions)]?.toStringAsFixed(1) ?? "0"}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: _getEmotionColor(_getPrimaryEmotion(emotions)),
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
                  itemCount: emotions.length,
                  itemBuilder: (context, index) {
                    final emotion = emotions.keys.elementAt(index);
                    final value = emotions.values.elementAt(index);
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
    );
  }

  Widget _buildServerRecordingsList() {
    if (_isLoadingServerData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text('Loading server recordings...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading server recordings',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServerRecordings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_serverRecordings.isEmpty) {
      return _buildEmptyState('No server recordings available');
    }

    return ListView.builder(
      itemCount: _serverRecordings.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final recording = _serverRecordings[index];
        final isPlaying =
            _currentlyPlayingPath == recording.streamUrl && _isPlaying;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.deepPurple,
                size: 30,
              ),
            ),
            title: Text(
              recording.filename,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${_formatDateTime(recording.createdAt)} • ${recording.sizeKb} KB',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Analyze'),
                  onPressed: () => _analyzeServerRecording(recording),
                ),
              ],
            ),
            onTap: () => _playRecording(recording.streamUrl),
          ),
        );
      },
    );
  }

  Future<void> _analyzeServerRecording(ServerRecording recording) async {
    if (_serverUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server URL not configured')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requesting analysis from server...')),
    );

    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/analyze_server_file'),
        body: {'filename': recording.filename},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final emotions = <String, double>{};
        final emotionsData = data['emotions'];
        if (emotionsData != null) {
          emotionsData.forEach((key, value) {
            if (value is num) {
              emotions[key] = value.toDouble();
            }
          });
        }

        final historyItem = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          serverFilePath: recording.streamUrl,
          name: recording.filename,
          timestamp: recording.createdAt,
          emotions: emotions,
          dominantEmotion: 'neutral',
          localFilePath: '',
        );

        _historyItems.insert(0, historyItem);

        _loadAnalyses();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis complete!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Get the primary emotion (highest value)
  String _getPrimaryEmotion(Map<String, double> emotions) {
    if (emotions.isEmpty) return 'Unknown';
    return emotions.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // Get color for emotion
  Color _getEmotionColor(String emotion) {
    return login.AppColors.getEmotionColor(emotion);
  }

  Future<void> _showDeleteAllDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Recordings'),
        content: const Text(
            'Are you sure you want to delete all recordings? This action cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAllRecordings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllRecordings() async {
    try {
      for (var file in _recordings) {
        await _deleteRecording(file);
      }
      if (mounted) {
        setState(() {
          _recordings = [];
        });
      }
    } catch (e) {
      debugPrint('Error deleting all recordings: $e');
    }
  }
}

class HistoryItem {
  final String id;
  final String? serverFilePath; // Path on the server instead of local path
  final String name;
  final DateTime timestamp;
  final Map<String, double> emotions;
  final String dominantEmotion;
  final String localFilePath; // Path to the JSON file on device

  HistoryItem({
    required this.id,
    this.serverFilePath,
    required this.name,
    required this.timestamp,
    required this.emotions,
    required this.dominantEmotion,
    required this.localFilePath,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json, String filePath) {
    // Parse emotions from JSON
    Map<String, double> emotions = {};
    if (json['emotions'] != null) {
      json['emotions'].forEach((key, value) {
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
    }

    // Find dominant emotion (highest value)
    String dominantEmotion = 'neutral';
    double maxValue = 0;
    emotions.forEach((emotion, value) {
      if (value > maxValue) {
        maxValue = value;
        dominantEmotion = emotion;
      }
    });

    // Generate ID from timestamp if not provided
    String id = json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Get timestamp
    DateTime timestamp;
    if (json['timestamp'] != null) {
      if (json['timestamp'] is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(json['timestamp']);
      } else {
        try {
          timestamp = DateTime.parse(json['timestamp'].toString());
        } catch (e) {
          timestamp = DateTime.now();
        }
      }
    } else {
      timestamp = DateTime.now();
    }

    return HistoryItem(
      id: id,
      serverFilePath: json['serverFilePath'],
      name: json['name'] ?? 'Analysis ${timestamp.toIso8601String()}',
      timestamp: timestamp,
      emotions: emotions,
      dominantEmotion: dominantEmotion,
      localFilePath: filePath,
    );
  }
}

class ServerRecording {
  final String filename;
  final String path;
  final double sizeKb;
  final DateTime createdAt;
  final String streamUrl;

  ServerRecording({
    required this.filename,
    required this.path,
    required this.sizeKb,
    required this.createdAt,
    required this.streamUrl,
  });

  factory ServerRecording.fromJson(
      Map<String, dynamic> json, String serverUrl) {
    final filename = json['filename'] as String;
    final streamPath = json['stream_url'] as String;

    // Create the full stream URL
    final streamUrl = serverUrl + streamPath;

    return ServerRecording(
      filename: filename,
      path: json['path'] as String,
      sizeKb: (json['size_kb'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      streamUrl: streamUrl,
    );
  }
}
