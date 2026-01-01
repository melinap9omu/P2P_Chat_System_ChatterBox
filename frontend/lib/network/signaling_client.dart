import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../services/API_service.dart';
import '../config/app_config.dart';

/// Represents a signaling message for WebRTC and key exchange.
class SignalingMessage {
  final String type;
  final String? payload;
  final int? targetUserId;
  final int? senderUserId;
  final Map<String, dynamic>? metadata;

  SignalingMessage({
    required this.type,
    this.payload,
    this.targetUserId,
    this.senderUserId,
    this.metadata,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      payload: json['payload'] as String?,
      targetUserId: json['targetUserId'] as int?,
      senderUserId: json['senderUserId'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'payload': payload,
      'targetUserId': targetUserId,
      'senderUserId': senderUserId,
      'metadata': metadata,
    };
  }
}

/// Interface for handling incoming signaling messages.
abstract class SignalingClientListener {
  void onMessage(SignalingMessage message);
  void onOpen();
  void onClose(int? code, String? reason);
  void onError(dynamic error);
}

/// Manages the WebSocket connection for signaling messages.
class SignalingClient {
  final int currentUserId;
  final String serverWsUrl;
  final String serverHttpBaseUrl;
  final String? _sessionCookie;

  SignalingClientListener? _listener;
  WebSocketChannel? _channel;

  // Added Completer to manage connection status for asynchronous waiting.
  final Completer<void> _connectedCompleter = Completer<void>();
  bool _isConnected = false;

  // --- Ping-pong related additions ---
  Timer? _pingTimer;
  // Define how often to send a ping message (e.g., every 30 seconds)
  final Duration _pingInterval = const Duration(seconds: 30);
  // -----------------------------------

  SignalingClient({
    required this.currentUserId,
    required this.serverWsUrl,
    required this.serverHttpBaseUrl,
    String? sessionCookie,
  }) : _sessionCookie = sessionCookie;

  // Setter method for the listener
  void setListener(SignalingClientListener listener) {
    _listener = listener;
  }

  // --- Crucial method added for external classes (like ChatDetailPage) to wait for connection ---
  Future<void> ensureConnected() {
    // Return the future of the Completer. If the connection is already complete,
    // it returns immediately. Otherwise, it waits.
    return _connectedCompleter.future;

  }
  // -----------------------------------------------------------------------------------------

  Future<void> connect() async {
    // If we are already connected and the completer hasn't been completed yet (unlikely, but safe check), complete it.
    if (_isConnected) {
      if (!_connectedCompleter.isCompleted) {
        _connectedCompleter.complete();
      }
      return;
    }

    try {
      final Map<String, dynamic> headers = {};
      headers['Cookie'] = _sessionCookie;
      print('Using session cookie for WebSocket connection');
      print('Connecting to WebSocket signaling server: $serverWsUrl');

      _channel = IOWebSocketChannel.connect(
        Uri.parse(serverWsUrl),
        headers: headers,
      );
     final  channel = _channel!;
     if (channel == null){
       print('Connection channel not connected');
     }

      // Listen to the stream
      channel.stream.listen(
            (message) {
          print('Signaling message received: $message');
          try {
            final Map<String, dynamic> json = jsonDecode(message);
            // Handle specific 'pong' messages directly or through SignalingMessage
            if (json['type'] == 'pong') {
              print('Received WebSocket pong from server');
              // Optionally, you could reset a timeout counter here if you were tracking server responsiveness
            } else {
              final signalingMessage = SignalingMessage.fromJson(json);
              _listener?.onMessage(signalingMessage);
            }
          } catch (e) {
            print('Error parsing signaling message JSON: $e');
            _listener?.onError('Failed to parse signaling message: $e');
          }
        },
        onDone: () {
          print('Signaling channel closed. Code: ${_channel?.closeCode}, Reason: ${_channel?.closeReason}');
          _isConnected = false;
          _listener?.onClose(_channel?.closeCode, _channel?.closeReason);
          _channel = null;
          _stopPingTimer(); // Stop ping timer on disconnect

          // Note: If the connection unexpectedly closes after being established,
          // the completer remains completed, which might be correct depending on desired behavior.
        },
        onError: (error) {
          print('Signaling channel error: $error');
          _isConnected = false;
          _listener?.onError(error);
          _channel = null;
          _stopPingTimer(); // Stop ping timer on error

          // If the connection failed during setup, complete the completer with an error.
          if (!_connectedCompleter.isCompleted) {
            _connectedCompleter.completeError(error);
          }
        },
        cancelOnError: true,
      );

      // Wait for the channel to confirm readiness.
      await _channel!.ready;

      // Connection successful: Mark as connected and complete the completer.
      _isConnected = true;
      if (!_connectedCompleter.isCompleted) {
        _connectedCompleter.complete();
      }
      _listener?.onOpen();
      print('Signaling connection established.');
      _startPingTimer(); // Start ping timer after successful connection

    } catch (e) {
      print('Failed to connect to signaling server: $e');
      _listener?.onError('Connection failed: $e');
      _channel = null;
      _isConnected = false;
      _stopPingTimer(); // Ensure timer is stopped if connection fails

      // If connection failed, complete the completer with an error.
      if (!_connectedCompleter.isCompleted) {
        _connectedCompleter.completeError(e);
      }
    }
  }

  void send(SignalingMessage message) {
    if (_channel != null && _isConnected) {
      final jsonString = jsonEncode(message.toJson());
      print('Sending signaling message: $jsonString');
      _channel!.sink.add(jsonString);
    } else {
      print('Signaling channel not connected. Cannot send message: ${message.type}');
      _listener?.onError('Signaling channel not connected.');
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      print('Disconnecting from signaling server...');
      _stopPingTimer(); // Stop ping timer before disconnecting
      await _channel!.sink.close();
      _channel = null;
      _isConnected = false;
      print('Signaling disconnected.');
    }
  }

  // --- New methods for ping-pong mechanism ---

  void _startPingTimer() {
    _stopPingTimer(); // Ensure any existing timer is stopped
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (_channel != null && _isConnected) {
        // Send a simple ping message. Your server should be configured to respond with a 'pong'.
        // The message type and content should match what your server expects for a ping.
        final pingMessage = {'type': 'ping', 'senderUserId': currentUserId};
        _channel!.sink.add(jsonEncode(pingMessage));
        print('Sent WebSocket ping to server');
      } else {
        print('WebSocket not connected, cannot send ping. Stopping ping timer.');
        _stopPingTimer();
      }
    });
    print('Ping timer started with interval: ${_pingInterval.inSeconds} seconds');
  }

  void _stopPingTimer() {
    if (_pingTimer != null && _pingTimer!.isActive) {
      _pingTimer!.cancel();
      _pingTimer = null;
      print('Ping timer stopped');
    }
  }
// ---------------------------------------------
}