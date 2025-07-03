import 'dart:async';
import 'dart:io';
import 'dart:convert';



import '../model/user.dart';
import '../webRTC/web_rtc_client.dart';
import '../network/signaling_client.dart';
import '../config/app_config.dart';
import '../crypto/rsa_key_manager.dart';


import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file_plus/open_file_plus.dart' as open_file_plus;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc; // Aliased to avoid conflict
// MessageType enum and ChatMessage class (Keeping them here for self-containment as you had them)
enum MessageType { text, file, notification }

class ChatMessage {
  final int senderId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? filePath; // For received files
  final String? fileId; // For file transfer tracking

  ChatMessage({
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.filePath,
    this.fileId,
  });
}
// End of MessageType and ChatMessage definition


class ChatDetailPage extends StatefulWidget {
  final int currentUserId;
  final int peerId;
  final String peerName; // Changed from userName to peerName as per constructor

  const ChatDetailPage({
    super.key,
    required this.currentUserId,
    required this.peerId,
    required this.peerName, // Changed from userName
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

// _ChatDetailPageState must implement WebRtcClientListener for callbacks
class _ChatDetailPageState extends State<ChatDetailPage> implements WebRtcClientListener {
  late SignalingClient _signalingClient;
  late WebRtcClient _webRtcClient;

  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = []; // List to hold chat messages
  final ScrollController _scrollController = ScrollController(); // For auto-scrolling chat

  // WebRTC related flags and renderers (kept for UI consistency, even if not fully used by you)
  final rtc.RTCVideoRenderer _localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer _remoteRenderer = rtc.RTCVideoRenderer();
  rtc.RTCPeerConnectionState _connectionState = rtc.RTCPeerConnectionState.RTCPeerConnectionStateNew;
  bool _isCallActive = false; // Flag to indicate if a call (and thus data channel) is active
  bool _keyExchangeComplete = false; // Flag for secure messaging readiness


  @override
  void initState() {
    super.initState();
    _initRenderers(); // Initialize video renderers
    _requestPermissions().then((granted) {
      if (granted) {
        _initializeClients(); // Initialize signaling and WebRTC clients
      } else {
        _addMessage(ChatMessage(
          senderId: 0, // System message
          content: 'Permissions not granted. Limited functionality.',
          timestamp: DateTime.now(),
          type: MessageType.notification,
        ));
      }
    });
  }

  // Request necessary permissions (camera, mic for calls, storage for files)
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.storage, // General storage permission for older Android/iOS photos
      Permission.photos, // iOS and Android 13+ photos
      Permission.mediaLibrary, // Android 13+ media access
    ].request();

    bool cameraGranted = statuses[Permission.camera] == PermissionStatus.granted;
    bool micGranted = statuses[Permission.microphone] == PermissionStatus.granted;
    bool storageGranted = true; // Assume granted by default or specific checks below

    if (Platform.isAndroid) {
      // For Android 13+, check photos/mediaLibrary
      if ((await Permission.photos.status).isGranted || (await Permission.mediaLibrary.status).isGranted) {
        storageGranted = true;
      } else {
        // For older Android, check storage directly
        storageGranted = statuses[Permission.storage] == PermissionStatus.granted;
      }
    } else if (Platform.isIOS) {
      storageGranted = statuses[Permission.photos] == PermissionStatus.granted;
    }

    bool allGranted = cameraGranted && micGranted && storageGranted;

    if (!allGranted) {
      print('One or more permissions denied.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera, Microphone, or Storage permissions denied.')),
        );
      }
    }
    return allGranted;
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // Initialize Signaling and WebRTC Clients
  void _initializeClients() async {
    // Ensure RSA keys are generated before attempting any crypto ops
    await RsaKeyManager.init();
    await RsaKeyManager.generateKeyPairIfNotExist(widget.currentUserId);

    _signalingClient = SignalingClient(
      currentUserId: widget.currentUserId,
      serverWsUrl: SERVER_WS_URL,
      serverHttpBaseUrl: SERVER_HTTP_BASE_URL,
    );

    _webRtcClient = WebRtcClient(
      currentUserId: widget.currentUserId,
      signalingClient: _signalingClient,
      listener: this, // This class will receive WebRTC events
    );

    _signalingClient.setListener(_webRtcClient);
    _signalingClient.connect(); // Connect to signaling server

    // Crucial for text messaging: Register specific listener for this peer
    _webRtcClient.addChatMessageListener(widget.peerId, (senderId, message) {
      _addMessage(ChatMessage(
        senderId: senderId,
        content: message,
        timestamp: DateTime.now(),
      ));
    });

    _addMessage(ChatMessage(
      senderId: 0,
      content: 'Connecting to signaling server...',
      timestamp: DateTime.now(),
      type: MessageType.notification,
    ));
  }

  @override
  void dispose() {
    _webRtcClient.removeChatMessageListener(widget.peerId); // Clean up listener
    _webRtcClient.disposePeerConnection(widget.peerId); // Dispose this specific connection
    _signalingClient.disconnect(); // Disconnect from signaling server
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper to add messages to the UI and scroll to bottom
  void _addMessage(ChatMessage message) {
    if (mounted) {
      setState(() {
        _messages.add(message);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // This method will be used by your friends for call functionality
  Future<void> _toggleCall() async {
    // This part is for your friends to implement video/audio call logic
    if (_isCallActive) {
      print('Ending call with ${widget.peerName}');
      _webRtcClient.disposePeerConnection(widget.peerId);
      setState(() {
        _isCallActive = false;
        _keyExchangeComplete = false;
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      });
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Call ended with ${widget.peerName}.',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    } else {
      print('Initiating call with ${widget.peerName}');
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Initiating call with ${widget.peerName}...',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
      try {
        await _webRtcClient.initiateCall(widget.peerId);
        setState(() {
          _isCallActive = true;
        });
      } catch (e) {
        print('Failed to initiate call: $e');
        _addMessage(ChatMessage(
          senderId: 0,
          content: 'Failed to initiate call: $e',
          timestamp: DateTime.now(),
          type: MessageType.notification,
        ));
        setState(() {
          _isCallActive = false;
        });
      }
    }
  }

  // Your core method for sending text messages
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Messages can only be sent once the WebRTC connection is active and key exchange is done
    if (!_isCallActive || !_keyExchangeComplete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send message: Call not active or key exchange not complete.')),
        );
      }
      return;
    }

    _addMessage(ChatMessage(
      senderId: widget.currentUserId,
      content: text,
      timestamp: DateTime.now(),
    ));
    _messageController.clear();

    try {
      await _webRtcClient.sendChatMessage(widget.peerId, text);
    } catch (e) {
      print('Error sending message: $e');
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Failed to send message: $e',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  // This method will be used by your friends for file sharing
  void _sendFile() async {
    if (!_isCallActive || !_keyExchangeComplete) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send file: Call not active or key exchange not complete.')),
        );
      }
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        if (file.path != null) {
          _addMessage(ChatMessage(
            senderId: widget.currentUserId,
            content: 'Sending file: ${file.name} (${(file.size / 1024).toStringAsFixed(2)} KB)',
            timestamp: DateTime.now(),
            type: MessageType.file,
            fileId: file.name,
          ));
          await _webRtcClient.sendFile(widget.peerId, file.path!);
        }
      } else {
        print('File picking canceled.');
      }
    } catch (e) {
      print('Error picking or sending file: $e');
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Failed to pick or send file: $e',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  // --- WebRtcClientListener Implementations ---
  // These methods are crucial for the WebRTC connection state,
  // even if you're only focusing on text messages initially.

  @override
  void onNewPeerConnected(int peerId, String peerName) {
    if (mounted && peerId == widget.peerId) {
      setState(() {
        _isCallActive = true;
      });
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Connected to ${widget.peerName}.',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  @override
  void onPeerDisconnected(int peerId) {
    if (mounted && peerId == widget.peerId) {
      setState(() {
        _isCallActive = false;
        _keyExchangeComplete = false;
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
      });
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Disconnected from ${widget.peerName}.',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  @override
  void onChatMessageReceived(int senderId, String message) {
    // This listener is also set up in _initializeClients via addChatMessageListener
    // This ensures incoming messages from the current peer are added to the chat.
    if (mounted && senderId == widget.peerId) {
      _addMessage(ChatMessage(
        senderId: senderId,
        content: message,
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  void onConnectionStateChange(rtc.RTCPeerConnectionState state, int peerId) {
    if (mounted && peerId == widget.peerId) {
      setState(() {
        _connectionState = state;
      });
      print('Connection State for ${widget.peerName}: $state');
      if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _addMessage(ChatMessage(
          senderId: 0,
          content: 'WebRTC connection established.',
          timestamp: DateTime.now(),
          type: MessageType.notification,
        ));
      } else if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _addMessage(ChatMessage(
          senderId: 0,
          content: 'WebRTC connection disconnected or failed.',
          timestamp: DateTime.now(),
          type: MessageType.notification,
        ));
      }
    }
  }

  @override
  void onError(String message) {
    if (mounted) {
      print('WebRTC Error: $message');
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Error: $message',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  @override
  void onKeyExchangeComplete(int peerId) {
    if (mounted && peerId == widget.peerId) {
      setState(() {
        _keyExchangeComplete = true;
      });
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'Secure key exchange complete with ${widget.peerName}. You can now send encrypted messages.',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  // Call-related listener methods (for friends to implement full video/audio)
  @override
  void onLocalStream(rtc.MediaStream stream) {
    if (mounted) {
      _localRenderer.srcObject = stream;
      print('Local stream set on renderer.');
    }
  }

  @override
  void onRemoteStream(rtc.MediaStream stream, int peerId) {
    if (mounted && peerId == widget.peerId) {
      _remoteRenderer.srcObject = stream;
      print('Remote stream set on renderer for $peerId.');
    }
  }

  // File transfer related listener methods (for friends to implement)
  @override
  void onFileMetadataReceived(int senderId, String fileId, String fileName, int fileSize, String fileType) {
    if (mounted && senderId == widget.peerId) {
      _addMessage(ChatMessage(
        senderId: senderId,
        content: 'Receiving file: $fileName (${(fileSize / 1024).toStringAsFixed(2)} KB)...',
        timestamp: DateTime.now(),
        type: MessageType.file,
        fileId: fileId,
      ));
    }
  }

  @override
  void onFileChunkReceived(String fileId, int currentChunk, int totalChunks) {
    // Optional: Update a progress bar for a specific fileId message
    // print('File $fileId: Received chunk $currentChunk/$totalChunks');
  }

  @override
  void onFileTransferComplete(String fileId, String fileName, int senderId, String filePath) {
    if (mounted && senderId == widget.peerId) {
      final index = _messages.indexWhere((msg) => msg.type == MessageType.file && msg.fileId == fileId);
      if (index != -1) {
        setState(() {
          _messages[index] = ChatMessage(
            senderId: senderId,
            content: 'Received file: $fileName (Tap to open)',
            timestamp: DateTime.now(),
            type: MessageType.file,
            filePath: filePath,
            fileId: fileId,
          );
        });
      } else {
        _addMessage(ChatMessage(
          senderId: senderId,
          content: 'Received file: $fileName (Tap to open)',
          timestamp: DateTime.now(),
          type: MessageType.file,
          filePath: filePath,
          fileId: fileId,
        ));
      }
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'File "$fileName" received successfully and saved to: $filePath',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }

  @override
  void onFileTransferError(String fileId, String message) {
    if (mounted) {
      _addMessage(ChatMessage(
        senderId: 0,
        content: 'File transfer error for "$fileId": $message',
        timestamp: DateTime.now(),
        type: MessageType.notification,
      ));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark background color
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212), // Darker app bar
        title: Text(
          widget.peerName, // Corrected from widget.userName
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // White icons in app bar
        actions: [
          // Call button (for friends to implement)
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _toggleCall, // This calls your _toggleCall method now
          ),
          // Video call button (for friends to implement)
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video call feature not implemented yet by friends.'),
                ),
              );
            },
          ),
          // More options menu (Clear Chat)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white), // Menu icon
            onSelected: (value) {
              if (value == 'clear_chat') {
                setState(() {
                  _messages.clear();
                });
                _addMessage(ChatMessage(
                  senderId: 0,
                  content: 'Chat cleared.',
                  timestamp: DateTime.now(),
                  type: MessageType.notification,
                ));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'clear_chat',
                child: Text('Clear Chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Video Renderers (shown if call is active) - for friends
          if (_isCallActive)
            Container(
              height: 200,
              color: Colors.black,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: rtc.RTCVideoView(
                      _remoteRenderer,
                      objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 90,
                      height: 120,
                      child: rtc.RTCVideoView(
                        _localRenderer,
                        objectFit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Connection and Key Exchange Status Indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Connection: ${_connectionState.toString().split('.').last}',
                    style: TextStyle(
                      color: _connectionState == rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
                Text(
                  'Key Exchange: ${_keyExchangeComplete ? 'Complete' : 'Pending'}',
                  style: TextStyle(
                    color: _keyExchangeComplete ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          // Chat messages display area
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Attach scroll controller
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length, // Use _messages list
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == widget.currentUserId; // Determine if message is from current user

                Color bubbleColor = Colors.white10; // Default for others/notifications
                Color textColor = Colors.white;

                if (isMe) {
                  bubbleColor = const Color(0xFF622F8A); // Purple for current user
                } else if (message.type == MessageType.notification) {
                  bubbleColor = Colors.grey.shade700; // Dark grey for notifications
                  textColor = Colors.white70;
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell( // Added InkWell for file messages
                      onTap: message.type == MessageType.file && message.filePath != null
                          ? () async {
                        final result = await open_file_plus.OpenFile.open(message.filePath!);
                        if (result.type != open_file_plus.ResultType.done) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open file: ${result.message}')),
                            );
                          }
                        }
                      }
                          : null,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (message.type != MessageType.notification)
                            Text(
                              isMe ? 'You' : widget.peerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white70),
                            ),
                          Text(
                            message.content,
                            style: TextStyle(color: textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Message Input field and buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                // File icon (for friends to implement)
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.white70),
                  onPressed: _sendFile, // This now calls your _sendFile method
                ),
                // TextField for message input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder( // Added focused border
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(), // Send on keyboard 'enter'
                  ),
                ),
                // Mic icon (for friends to implement)
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.white70),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice input not implemented yet by friends.'),
                      ),
                    );
                  },
                ),
                // Send icon - triggers _sendMessage
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}