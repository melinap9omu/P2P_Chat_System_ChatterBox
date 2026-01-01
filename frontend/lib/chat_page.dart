// lib/chat_page.dart - Updated sections

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'profile_page.dart';
import 'chatdetail_page.dart';
import '../model/user.dart';
import '../services/API_service.dart';
import '../services/websocket_service.dart'; // Add this import

class ChatPage extends StatefulWidget {
  final int currentUserid;
  final String currentUsername;
  final VoidCallback onLogout;
  final String currentUserEmail;
  final String currentUserPublicKeyPem;
  final String currentUserPrivateKeyPem;

  const ChatPage({
    super.key,
    required this.currentUserid,
    required this.currentUsername,
    required this.onLogout,
    required this.currentUserEmail,
    required this.currentUserPublicKeyPem,
    required this.currentUserPrivateKeyPem
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _selectedIndex = 0;

  final List<String> labels = ['Chat', 'Profile'];
  final List<IconData> icons = [
    Icons.chat_bubble_outline,
    Icons.person_outline
  ];

  final TextEditingController _searchController = TextEditingController();

  List<User> _allOnlineUsers = [];
  List<User> _filteredOnlineUsers = [];

  bool _isLoadingUsers = true;
  String? _userFetchError;

  Timer? _refreshTimer;
  final ApiService _apiService = ApiService();
  final WebSocketService _webSocketService = WebSocketService(); // Add WebSocket service

  // WebSocket connection state
  WebSocketState _wsState = WebSocketState.disconnected;
  late StreamSubscription _wsStateSubscription;
  late StreamSubscription _onlineUsersSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_searchUsers);
    _initializeConnections();
  }

  Future<void> _initializeConnections() async {
    // Initialize API service
    await _apiService.ensureInitialized();

    // Set up WebSocket listeners
    _wsStateSubscription = _webSocketService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _wsState = state;
        });

        if (state == WebSocketState.connected) {
          // Fetch online users when WebSocket connects
          _fetchOnlineUsers();
        }
      }
    });

    // Listen for online users updates from WebSocket
    _onlineUsersSubscription = _webSocketService.onlineUsersStream.listen((users) {
      if (mounted) {
        try {
          final List<User> fetchedUsers = users
              .map((json) => User.fromJson(json))
              .where((user) => user.id != widget.currentUserid)
              .toList();

          setState(() {
            _allOnlineUsers = fetchedUsers;
            _searchUsers();
            _isLoadingUsers = false;
          });

          print('WebSocket: Updated online users list: ${fetchedUsers.length} users');
        } catch (e) {
          print('Error processing WebSocket online users: $e');
        }
      }
    });

    // Connect to WebSocket
    await _webSocketService.connect(widget.currentUserid);

    // Start periodic refresh as fallback
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_wsState != WebSocketState.connected) {
        _fetchOnlineUsers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    _wsStateSubscription.cancel();
    _onlineUsersSubscription.cancel();
    _webSocketService.disconnect(); // Disconnect WebSocket
    super.dispose();
  }

  Future<void> _fetchOnlineUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoadingUsers = true;
      _userFetchError = null;
    });

    try {
      await _apiService.ensureInitialized();

      final response = await _apiService.dio.get('/users/online',
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data;
        final List<User> fetchedUsers = jsonList
            .map((json) => User.fromJson(json))
            .where((user) => user.id != widget.currentUserid)
            .toList();

        setState(() {
          _allOnlineUsers = fetchedUsers;
          _searchUsers();
          _isLoadingUsers = false;
        });

        print('HTTP: Fetched ${_allOnlineUsers.length} online users');
      } else {
        String message = 'Failed to fetch online users (Status: ${response.statusCode}).';
        if (response.data is Map<String, dynamic> && response.data.containsKey('message')) {
          message = response.data['message'];
        } else if (response.data is String) {
          try {
            message = jsonDecode(response.data)['message'] ?? message;
          } catch (e) {
            // Use default message
          }
        }
        setState(() {
          _userFetchError = message;
          _isLoadingUsers = false;
        });
        print('Failed to fetch online users: ${response.statusCode} - ${response.data}');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Network error: ${e.message}';
      if (e.response != null) {
        if (e.response!.data is Map && e.response!.data.containsKey('message')) {
          errorMessage = e.response!.data['message'];
        } else if (e.response!.data is String) {
          try {
            errorMessage = jsonDecode(e.response!.data)['message'] ?? errorMessage;
          } catch (jsonError) {
            errorMessage = 'Server error (${e.response!.statusCode}): ${e.response!.statusMessage ?? 'Unknown error'}.';
          }
        } else {
          errorMessage = 'Server error (${e.response!.statusCode}): ${e.response!.statusMessage ?? 'Unknown error'}.';
        }
      }
      setState(() {
        _userFetchError = errorMessage;
        _isLoadingUsers = false;
      });
      print('Error fetching online users (DioException): $e');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userFetchError = 'Unexpected error: $e';
        _isLoadingUsers = false;
      });
      print('Error fetching online users: $e');
    }
  }

  void _searchUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOnlineUsers = _allOnlineUsers
          .where((user) => user.fullName.toLowerCase().contains(query))
          .toList();
    });
  }

  void _navigateToChat(User peerUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailPage(
          currentUserId: widget.currentUserid,
          peerId: peerUser.id,
          peerName: peerUser.fullName,
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          currentUserid: widget.currentUserid,
          currentUsername: widget.currentUsername,
          currentUserEmail: widget.currentUserEmail,
          currentUserPublicKeyPem: widget.currentUserPublicKeyPem,
          currentUserPrivateKeyPem: widget.currentUserPrivateKeyPem,
        ),
      ),
    );
  }

  // Add connection status indicator
  Widget _buildConnectionStatus() {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (_wsState) {
      case WebSocketState.connected:
        statusColor = Colors.greenAccent;
        statusText = 'Connected';
        statusIcon = Icons.wifi;
        break;
      case WebSocketState.connecting:
        statusColor = Colors.orangeAccent;
        statusText = 'Connecting...';
        statusIcon = Icons.wifi_off;
        break;
      case WebSocketState.reconnecting:
        statusColor = Colors.orangeAccent;
        statusText = 'Reconnecting...';
        statusIcon = Icons.wifi_off;
        break;
      case WebSocketState.disconnected:
        statusColor = Colors.redAccent;
        statusText = 'Disconnected';
        statusIcon = Icons.wifi_off;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: GoogleFonts.almarai(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Rest of your existing methods remain the same...
  Widget _buildUserListContent() {
    if (_isLoadingUsers) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8C5DB2)),
      );
    }

    if (_userFetchError != null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userFetchError!,
                      style: GoogleFonts.almarai(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.redAccent,
                      ),
                      child: ElevatedButton(
                        onPressed: _fetchOnlineUsers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Retry',
                          style: GoogleFonts.almarai(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_filteredOnlineUsers.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isEmpty ? Icons.people_outline : Icons.search_off,
                      size: 48,
                      color: Colors.white60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchController.text.isEmpty
                          ? 'No other users online.\nPull down to refresh.'
                          : 'No matching users found.',
                      style: GoogleFonts.almarai(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filteredOnlineUsers.length,
      itemBuilder: (context, index) {
        final peerUser = _filteredOnlineUsers[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF8C5DB2),
              child: Text(
                peerUser.firstname.isNotEmpty
                    ? peerUser.firstname[0].toUpperCase()
                    : '?',
                style: GoogleFonts.almarai(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              peerUser.fullName,
              style: GoogleFonts.almarai(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Online • ID: ${peerUser.id}',
              style: GoogleFonts.almarai(
                color: Colors.greenAccent,
                fontSize: 13,
              ),
            ),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  color: Colors.greenAccent,
                  size: 12,
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _navigateToChat(peerUser),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Custom AppBar with connection status
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chat - ${widget.currentUsername}',
                        style: GoogleFonts.almarai(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _fetchOnlineUsers,
                      tooltip: 'Refresh Online Users',
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: widget.onLogout,
                      tooltip: 'Logout',
                    ),
                  ],
                ),
                // Connection status
                _buildConnectionStatus(),
              ],
            ),
          ),

          // Search Bar
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _searchController,
              style: GoogleFonts.almarai(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                hintText: 'Search users...',
                hintStyle: GoogleFonts.almarai(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white60),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers();
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8C5DB2), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),

          // Online Users Count
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Online Users: ${_filteredOnlineUsers.length}',
                  style: GoogleFonts.almarai(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // User List with RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchOnlineUsers,
              color: const Color(0xFF8C5DB2),
              backgroundColor: Colors.black,
              child: Container(
                color: Colors.black,
                child: _buildUserListContent(),
              ),
            ),
          ),
        ],
      ),
      // Rest of the bottom navigation bar remains the same...
      bottomNavigationBar: Container(
        color: Colors.black,
        child: SafeArea(
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(2, (index) {
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });

                    if (index == 0) {
                      // Chat tab (current page)
                    }
                     else if (index == 1) {
                      // Profile tab
                      _navigateToProfile();
                    }
                  },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF8C5DB2)
                                : Colors.white.withOpacity(0.1),
                            border: isSelected
                                ? null
                                : Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icons[index],
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[index],
                          style: GoogleFonts.almarai(
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),

                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}