import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uuid/uuid.dart';
import 'web_file_upload.dart';
import 'config.dart';

void main() {
  runApp(const AnswerSheetEvaluatorApp());
}

class AnswerSheetEvaluatorApp extends StatelessWidget {
  const AnswerSheetEvaluatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Answer Sheet Evaluator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  FileData? _questionPaper;
  FileData? _answerKey;
  String? _sessionId;
  IO.Socket? _socket;
  List<AnswerSheetImage> _uploadedSheets = [];
  bool _isConnected = false;
  bool _isUploading = false;
  
  // Evaluation state
  String? _currentEvaluatingImage;
  Map<String, dynamic>? _currentEvaluation;
  bool _isEvaluating = false;

  @override
  void initState() {
    super.initState();
  }

  void _connectToSocket(String sessionId) {
    try {
      _socket = IO.io(AppConfig.websocketUrl, <String, dynamic>{
        'transports': ['polling', 'websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
        'extraHeaders': {
          'ngrok-skip-browser-warning': 'true',
        },
      });

      _socket!.connect();

      _socket!.onConnect((_) {
        print('Connected to server');
        setState(() {
          _isConnected = true;
        });
        
        // Join the session room
        _socket!.emit('join', {'session_id': sessionId});
      });

      _socket!.on('joined', (data) {
        print('Joined session: $data');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to session: $sessionId')),
          );
        }
      });

      _socket!.on('new_upload', (data) {
        print('New upload received: ${data['page']}');
        
        if (data != null && data['img'] != null) {
          setState(() {
            _uploadedSheets.add(AnswerSheetImage(
              pageNumber: data['page']?.toString() ?? 'Unknown',
              base64Image: data['img'],
              timestamp: DateTime.now(),
            ));
            // Store current image for evaluation
            _currentEvaluatingImage = data['img'];
            _isEvaluating = true;
          });
          
          // Show notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New answer sheet page ${data['page']} received! Evaluating...'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    // Scroll to new image
                  },
                ),
              ),
            );
          }
        }
      });

      _socket!.on('evaluation_result', (data) {
        print('Evaluation result received: ${data['page']}');
        
        if (data != null && data['evaluation'] != null) {
          setState(() {
            _currentEvaluation = data['evaluation'];
            _isEvaluating = false;
          });
          
          // Navigate to evaluation page
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EvaluationPage(
                  image: _currentEvaluatingImage!,
                  evaluation: _currentEvaluation!,
                ),
              ),
            );
          }
        }
      });

      _socket!.onConnectError((error) {
        print('Connection error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection error: $error')),
          );
        }
      });

      _socket!.onDisconnect((_) {
        setState(() {
          _isConnected = false;
        });
        print('Disconnected from server');
      });
    } catch (e) {
      print('Socket error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  Future<void> _selectQuestionPaper() async {
    try {
      final fileData = await pickPdf('Question Paper');
      if (fileData != null) {
        setState(() {
          _questionPaper = fileData;
        });
      }
    } catch (e) {
      print('Error selecting file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _selectAnswerKey() async {
    try {
      final fileData = await pickPdf('Answer Key');
      if (fileData != null) {
        setState(() {
          _answerKey = fileData;
        });
      }
    } catch (e) {
      print('Error selecting file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _uploadFiles() async {
    if (_questionPaper == null || _answerKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both question paper and answer key')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Generate session ID
      final sessionId = const Uuid().v4();
      setState(() {
        _sessionId = sessionId;
      });

      // Convert FileData to http.MultipartFile for upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/upload_docs'),
      );

      // Add ngrok bypass header
      request.headers['ngrok-skip-browser-warning'] = 'true';

      request.fields['session_id'] = sessionId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'question',
          _questionPaper!.bytes,
          filename: _questionPaper!.name,
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'answer',
          _answerKey!.bytes,
          filename: _answerKey!.name,
        ),
      );

      print('Sending upload request to: ${AppConfig.serverUrl}/upload_docs');
      print('Session ID: $sessionId');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Response status: ${response.statusCode}');
      print('Response body: $responseBody');

      if (response.statusCode == 200) {
        // Connect to socket
        _connectToSocket(sessionId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Files uploaded successfully! QR Code generated.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $responseBody')),
          );
        }
      }
    } catch (e) {
      print('Upload error: $e');
      print('Error details: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Upload Error'),
                    content: Text(e.toString()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Uint8List? _decodeBase64Image(String base64String) {
    try {
      return base64Decode(base64String);
    } catch (e) {
      print('Error decoding base64: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Answer Sheet Evaluator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload Section
            if (_sessionId == null) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.upload_file,
                            color: Theme.of(context).colorScheme.primary,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Upload Documents',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your question paper and answer key to start a session',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FileUploadWidget(
                        label: 'Question Paper (PDF)',
                        file: _questionPaper,
                        onSelect: _selectQuestionPaper,
                      ),
                      const SizedBox(height: 16),
                      FileUploadWidget(
                        label: 'Answer Key (PDF)',
                        file: _answerKey,
                        onSelect: _selectAnswerKey,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _uploadFiles,
                          icon: _isUploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload),
                          label: Text(_isUploading ? 'Uploading...' : 'Upload & Generate Session'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // QR Code Section
            if (_sessionId != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Session QR Code',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _sessionId!,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Session ID: $_sessionId',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Listening for uploads...',
                              style: TextStyle(
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Uploaded Sheets Grid
            if (_uploadedSheets.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.photo_library,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
            Text(
                            'Uploaded Answer Sheets',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_uploadedSheets.length} page${_uploadedSheets.length > 1 ? 's' : ''} received',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _uploadedSheets.length,
                        itemBuilder: (context, index) {
                          final sheet = _uploadedSheets[index];
                          return AnswerSheetCard(
                            sheet: sheet,
                            decodeBase64: _decodeBase64Image,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FileUploadWidget extends StatelessWidget {
  final String label;
  final FileData? file;
  final VoidCallback onSelect;

  const FileUploadWidget({
    super.key,
    required this.label,
    required this.file,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(
            color: file == null ? Colors.grey.shade300 : Colors.green.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: file == null ? Colors.grey.shade50 : Colors.green.shade50,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: file == null
                    ? Colors.grey.shade600
                    : Colors.green.shade700,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: file == null ? Colors.grey.shade900 : Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file == null ? 'Tap to select PDF file' : file!.name,
                      style: TextStyle(
                        fontSize: 12,
                        color: file == null ? Colors.grey.shade600 : Colors.green.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (file != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 28,
                ),
              ] else ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey.shade600,
                  size: 28,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AnswerSheetImage {
  final String pageNumber;
  final String base64Image;
  final DateTime timestamp;

  AnswerSheetImage({
    required this.pageNumber,
    required this.base64Image,
    required this.timestamp,
  });
}

class AnswerSheetCard extends StatelessWidget {
  final AnswerSheetImage sheet;
  final Uint8List? Function(String) decodeBase64;

  const AnswerSheetCard({
    super.key,
    required this.sheet,
    required this.decodeBase64,
  });

  @override
  Widget build(BuildContext context) {
    final imageBytes = decodeBase64(sheet.base64Image);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: imageBytes != null
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.red.shade50,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Page ${sheet.pageNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${sheet.timestamp.hour}:${sheet.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------
// 📊 Evaluation Page with Left/Right Split
// -------------------------------
class EvaluationPage extends StatefulWidget {
  final String image;
  final Map<String, dynamic> evaluation;

  const EvaluationPage({
    super.key,
    required this.image,
    required this.evaluation,
  });

  @override
  State<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends State<EvaluationPage> with TickerProviderStateMixin {
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Sheet Evaluation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Left Side: Scanned Image with Neon Green Scanning Line
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.grey.shade100,
              child: Card(
                elevation: 8,
                child: Stack(
                  children: [
                    // Scanned Image
                    Center(
                      child: Image.memory(
                        Uint8List.fromList(base64Decode(widget.image)),
                        fit: BoxFit.contain,
                      ),
                    ),
                    
                    // Neon Green Scanning Line Animation
                    AnimatedBuilder(
                      animation: _scanLineController,
                      builder: (context, child) {
                        final position = _scanLineController.value * 2 - 1; // -1 to 1
                        return Positioned(
                          top: (MediaQuery.of(context).size.height * 0.5) + (position * MediaQuery.of(context).size.height * 0.3),
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.green.shade400,
                                  Colors.green.shade300,
                                  Colors.green.shade400,
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade400.withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Evaluating Text
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Evaluating...',
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Side: Evaluation Results (Dummy)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: Theme.of(context).colorScheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Evaluation Results',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Score Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            'Score',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.evaluation['score']}/${widget.evaluation['total_marks']}',
                            style: TextStyle(
                              fontSize: 48,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          color: Colors.green.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Correct',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '${widget.evaluation['correct_answers']}/${widget.evaluation['total_questions']}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          color: Colors.red.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.cancel, color: Colors.red.shade700, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'Incorrect',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  '${widget.evaluation['total_questions'] - widget.evaluation['correct_answers']}/${widget.evaluation['total_questions']}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Placeholder for Future Implementation
                  Card(
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange.shade300, width: 2, style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Detailed evaluation results will be displayed here',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}