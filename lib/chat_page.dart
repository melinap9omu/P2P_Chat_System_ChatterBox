import 'dart:convert';
import 'dart:async'; // Added for Future.delayed in mock fetch

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';


import '../config/app_config.dart';
import 'profile_page.dart';
import 'chatdetail_page.dart';

import '../model/user.dart';
// import 'friend_page.dart'; // REMOVED: This import is no longer needed

class ChatPage extends StatefulWidget {
  final String currentUserid;
  final String currentUsername;

  final VoidCallback onLogout;

  const ChatPage({
    super.key,
    required this.currentUserid,
    required this.currentUsername,
   
    required this.onLogout,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _selectedIndex = 0; // Remains 0 for Chat tab initially

  // Keep labels and icons as they were, to preserve the UI
  final List<String> labels = ['Chat', 'Friends', 'Profile'];
  final List<IconData> icons = [
    Icons.chat_bubble_outline,
    Icons.group_outlined, // Icon for 'Friends' tab remains
    Icons.person_outline
  ];

  final TextEditingController _searchController = TextEditingController();

  List<User> _allOnlineUsers = [];
  List<User> _filteredOnlineUsers = [];

  bool _isLoadingUsers = true;
  String? _userFetchError;

  // Assuming filteredChats is for a different purpose or will be populated later
  List<Map<String, String>> filteredChats = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_searchUsers);
    _fetchOnlineUsers();
  }

  Future<void> _fetchOnlineUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _userFetchError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$SERVER_HTTP_BASE_URL/users/online'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<User> fetchedUsers = jsonList
            .map((json) => User.fromJson(json))
            .where((user) => user.id != widget.currentUserid)
            .toList();

        setState(() {
          _allOnlineUsers = fetchedUsers;
          _searchUsers(); // Filter users after fetching
          _isLoadingUsers = false;
        });
        print(
            'Fetched online users: ${_allOnlineUsers.map((u) => u.fullName).join(', ')}');
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        setState(() {
          _userFetchError =
              errorData['message'] ?? 'Failed to fetch online users.';
          _isLoadingUsers = false;
        });
        print(
            'Failed to fetch online users: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _userFetchError = 'Network error: $e';
        _isLoadingUsers = false;
      });
      print('Error fetching online users: $e');
    }
  }

  void _searchUsers() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredOnlineUsers = _allOnlineUsers
          .where((user) => user.fullName.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 25, 25, 25),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
        title: Text(
          'Chat - ${widget.currentUsername}',
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchOnlineUsers,
            tooltip: 'Refresh Online Users',
          ),
         IconButton(
  icon: const Icon(Icons.logout, color: Colors.white),
  onPressed: () async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.almarai(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      widget.onLogout();
    }
  },
  tooltip: 'Logout',
),
        ],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white12,
                hintText: 'Search users...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
          Expanded(
            child: _isLoadingUsers
                ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF622F8A)),
            )
                : _userFetchError != null
                ? Center(
              child: Text(
                _userFetchError!,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
                : _filteredOnlineUsers.isEmpty
                ? Center(
              child: Text(
                _searchController.text.isEmpty
                    ? 'No other users online.'
                    : 'No matching users found.',
                style: const TextStyle(
                    color: Colors.white60, fontSize: 16),
              ),
            )
                : ListView.builder(
              itemCount: _filteredOnlineUsers.length,
              itemBuilder: (context, index) {
                final peerUser = _filteredOnlineUsers[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailPage(
                           currentUserid: widget.currentUserid,
                          peerId: peerUser.id,
                          peerName: peerUser.fullName,
                          // Removed webRtcClient and signalingClient as ChatDetailPage will manage its own
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Text(
                        peerUser.firstname.isNotEmpty
                            ? peerUser.firstname[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      peerUser.fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Online (ID: ${peerUser.id})',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13),
                    ),
                    trailing: const Icon(Icons.circle,
                        color: Colors.greenAccent, size: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 25, 25, 25),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 70,
                color: const Color.fromARGB(255, 14, 14, 14),
              ),
            ),
            Positioned(
              top: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                // List.generate(3, ...) remains unchanged to keep 3 tabs
                children: List.generate(3, (index) {
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      if (index == 0) { // Chat tab (current page)
                        // No navigation needed, just update selected index if desired
                        setState(() {
                          _selectedIndex = index;
                        });
                      } else if (index == 1) { // Friends tab
                        // REMOVED: Navigation to FriendPage
                        // The UI remains, but tapping this tab will now do nothing
                        print('Friends tab tapped, but functionality is removed.');
                        // You could add a SnackBar here to inform the user:
                        // ScaffoldMessenger.of(context).showSnackBar(
                        //   const SnackBar(content: Text('Friends feature not available yet!')),
                        // );
                      } else if (index == 2) { // Profile tab
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Pass current user ID and username to ProfilePage
                              builder: (context) => ProfilePage(
                                currentUserid: widget.currentUserid,
                                currentUsername: widget.currentUsername,
                            
                            
                              )),
                        );
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 3, // Remains divided by 3 for 3 tabs
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? const Color.fromARGB(255, 98, 48, 139)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              icons[index],
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[index],
                            style: GoogleFonts.almarai(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}