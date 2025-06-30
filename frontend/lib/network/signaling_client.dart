import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final String signalingServerUrl;
  final SignalingClientListener listener;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  SignalingClient({
    required this.signalingServerUrl,
    required this.listener,
  });

  Future<void> connect() async {
    try {
      print('Connecting to WebSocket signaling server: $signalingServerUrl');
      _channel = WebSocketChannel.connect(Uri.parse(signalingServerUrl));

      _channel!.stream.listen(
            (message) {
          print('Signaling message received: $message');
          try {
            final Map<String, dynamic> json = jsonDecode(message);
            final signalingMessage = SignalingMessage.fromJson(json);
            listener.onMessage(signalingMessage);
          } catch (e) {
            print('Error parsing signaling message JSON: $e');
            listener.onError('Failed to parse signaling message: $e');
          }
        },
        onDone: () {
          print('Signaling channel closed. Code: ${_channel!.closeCode}, Reason: ${_channel!.closeReason}');
          _isConnected = false;
          listener.onClose(_channel!.closeCode, _channel!.closeReason);
          _channel = null;
        },
        onError: (error) {
          print('Signaling channel error: $error');
          _isConnected = false;
          listener.onError(error);
          _channel = null;
        },
        cancelOnError: true,
      );

      // Wait a short time before confirming connection
      await Future.delayed(const Duration(milliseconds: 500));
      _isConnected = true;
      listener.onOpen();
      print('Signaling connection established.');
    } catch (e) {
      print('Failed to connect to signaling server: $e');
      listener.onError('Connection failed: $e');
      _channel = null;
      _isConnected = false;
    }
  }

  void send(SignalingMessage message) {
    if (_channel != null && _isConnected) {
      final jsonString = jsonEncode(message.toJson());
      print('Sending signaling message: $jsonString');
      _channel!.sink.add(jsonString);
    } else {
      print('Signaling channel not connected. Cannot send message: ${message.type}');
      listener.onError('Signaling channel not connected.');
    }
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      print('Disconnecting from signaling server...');
      await _channel!.sink.close();
      _channel = null;
      _isConnected = false;
      print('Signaling disconnected.');
    }
  }
}
