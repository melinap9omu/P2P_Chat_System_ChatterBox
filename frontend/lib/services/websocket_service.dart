// lib/services/websocket_service.dart

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/app_config.dart';
import '../services/API_service.dart';

enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class WebSocketService {
  WebSocketChannel? _channel;
  static final WebSocketService _instance = WebSocketService._internal();

  final ApiService _apiService = ApiService();

  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // State management
  WebSocketState _state = WebSocketState.disconnected;
  final StreamController<WebSocketState> _stateController = StreamController<WebSocketState>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _onlineUsersController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectDelay = const Duration(seconds: 3);
  final Duration _pingInterval = const Duration(seconds: 30);

  int? _currentUserId;

  // Getters for streams
  Stream<WebSocketState> get stateStream => _stateController.stream;
  Stream<List<Map<String, dynamic>>> get onlineUsersStream => _onlineUsersController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  WebSocketState get state => _state;
  bool get isConnected => _state == WebSocketState.connected;

  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
      print('WebSocket state changed to: $_state');
    }
  }

  Future<void> connect(int userId) async {
    if (_state == WebSocketState.connecting || _state == WebSocketState.connected) {
      print('WebSocket already connecting or connected');
      return;
    }

    _currentUserId = userId;
    _updateState(WebSocketState.connecting);

    try {
      // Ensure ApiService is initialized and has loaded cookies
      await _apiService.ensureInitialized();

      final wsUrl = CHAT_WS_URL;
      final wsUri = Uri.parse(wsUrl);
      print('Connecting to WebSocket: $wsUrl');

      // Retrieve cookies stored by ApiService
      final List<Cookie> cookies = await _apiService.cookieJar.loadForRequest(wsUri);

      // Safely extract JSESSIONID cookie
      Cookie? jsessionidCookie;
      try {
        jsessionidCookie = cookies.firstWhere((cookie) => cookie.name == 'JSESSIONID');
      } catch (e) {
        jsessionidCookie = null;
      }

      // Prepare headers
      final Map<String, dynamic> headers = {
        'userId': userId.toString(),
      };

      if (jsessionidCookie != null && jsessionidCookie.value.isNotEmpty) {
        headers['Cookie'] = '${jsessionidCookie.name}=${jsessionidCookie.value}';
        print('WebSocketService: Including JSESSIONID in headers for AuthFilter.');
      } else {
        print('WebSocketService: JSESSIONID not found. WebSocket connection might fail AuthFilter.');
      }

      // Connect WebSocket
      _channel = IOWebSocketChannel.connect(wsUrl, headers: headers);

      _channel!.stream.listen(
            (message) => _handleMessage(message),
        onError: (error) {
          print('WebSocket error: $error');
          _handleError(error);
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnection();
        },
      );

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;
      _startPingTimer();

      print('WebSocket connected for user $userId');
    } catch (e) {
      print('Failed to connect WebSocket: $e');
      _handleError(e);
    }
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      print('Received WebSocket message: $data');

      switch (data['type']) {
        case 'online_users_update':
          _handleOnlineUsersUpdate(data);
          break;
        case 'user_online':
          _handleUserOnline(data);
          break;
        case 'user_offline':
          _handleUserOffline(data);
          break;
        case 'pong':
          print('Received pong from server');
          break;
        case 'error':
          print('Server error: ${data['message']}');
          break;
        default:
          print('Unknown message type: ${data['type']}');
      }

      _messageController.add(data);
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  void _handleOnlineUsersUpdate(Map<String, dynamic> data) {
    try {
      final usersData = data['data'] as List<dynamic>?;
      if (usersData != null) {
        final users = usersData.cast<Map<String, dynamic>>();
        _onlineUsersController.add(users);
        print('Updated online users: ${users.length} users');
      }
    } catch (e) {
      print('Error handling online users update: $e');
    }
  }

  void _handleUserOnline(Map<String, dynamic> data) {
    try {
      final userData = data['data'] as Map<String, dynamic>?;
      if (userData != null) {
        print('User came online: ${userData['fullName']} (ID: ${userData['id']})');
        // Request updated online users list
        requestOnlineUsers();
      }
    } catch (e) {
      print('Error handling user online: $e');
    }
  }

  void _handleUserOffline(Map<String, dynamic> data) {
    try {
      final userData = data['data'] as Map<String, dynamic>?;
      if (userData != null) {
        print('User went offline: ${userData['fullName']} (ID: ${userData['id']})');
        // Request updated online users list
        requestOnlineUsers();
      }
    } catch (e) {
      print('Error handling user offline: $e');
    }
  }


  void _handleError(dynamic error) {
    print('WebSocket error occurred: $error');
    _updateState(WebSocketState.disconnected);
    _stopPingTimer();

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnection();
    } else {
      print('Max reconnection attempts reached. Giving up.');
    }
  }

  void _handleDisconnection() {
    _updateState(WebSocketState.disconnected);
    _stopPingTimer();
    _channel = null;

    if (_currentUserId != null && _reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnection();
    }
  }

  void _attemptReconnection() {
    if (_currentUserId == null) return;

    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);

    print('Attempting to reconnect... (Attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      connect(_currentUserId!);
    });
  }

  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_state == WebSocketState.connected) {
        sendMessage({'type': 'ping'});
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _state == WebSocketState.connected) {
      try {
        _channel!.sink.add(jsonEncode(message));
        print('Sent WebSocket message: $message');
      } catch (e) {
        print('Error sending WebSocket message: $e');
      }
    } else {
      print('Cannot send message: WebSocket not connected');
    }
  }

  void requestOnlineUsers() {
    sendMessage({
      'type': 'request_online_users',
      'message': 'Requesting current online users list'
    });
  }

  void disconnect() {
    print('Disconnecting WebSocket...');
    _reconnectTimer?.cancel();
    _stopPingTimer();
    _channel?.sink.close();
    _channel = null;
    _currentUserId = null;
    _reconnectAttempts = 0;
    _updateState(WebSocketState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _onlineUsersController.close();
    _messageController.close();
  }
}
