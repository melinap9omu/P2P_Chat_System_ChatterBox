import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'friend_page.dart';
import 'profile_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _selectedIndex = 0;

  final List<String> labels = ['Chat', 'Friends', 'Profile'];
  final List<IconData> icons = [
    Icons.chat_bubble_outline,
    Icons.group_outlined,
    Icons.person_outline
  ];

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> allChats = [
    {'name': 'Jonas', 'message': 'How are you?', 'time': '2 min ago'},
    {'name': 'Ethan', 'message': 'Hi!', 'time': '15 min ago'},
    {'name': 'Oliver', 'message': "What's up?", 'time': '1 hour ago'},
    {'name': 'Olivia', 'message': 'See u tomorrow', 'time': '9 hour ago'},
    {'name': 'John', 'message': 'See u tomorrow', 'time': '1 day ago'},
    {'name': 'Lily', 'message': 'See u tomorrow', 'time': '5 day ago'},
  ];

  List<Map<String, String>> filteredChats = [];

  @override
  void initState() {
    super.initState();
    filteredChats = List.from(allChats); // Initially show all chats
    _searchController.addListener(_searchChats); // Listen for changes
  }

  void _searchChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredChats = allChats
          .where((chat) => chat['name']!.toLowerCase().contains(query))
          .toList();
    });
  }

  void _loadMoreChats() {
    setState(() {
      allChats.addAll([
        {'name': 'Sophia', 'message': 'Let\'s catch up!', 'time': '6 day ago'},
        {'name': 'Noah', 'message': 'Yo!', 'time': '7 day ago'},
        {'name': 'Emma', 'message': 'Nice to meet you.', 'time': '8 day ago'},
      ]);
      _searchChats(); // Update filter with existing query
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // Clean up the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white12,
                hintText: 'Search users or chats...',
                hintStyle: const TextStyle(color: Colors.white60),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: filteredChats.isEmpty
                ? const Center(
                    child: Text(
                      'No matching chats.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredChats.length,
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.person, color: Colors.white70),
                        ),
                        title: Text(
                          chat['name']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          chat['message']!,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Text(
                          chat['time']!,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadMoreChats,
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Color(0xFF622F8A)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 70,
                color: Colors.black,
              ),
            ),
            Positioned(
              top: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  final isSelected = _selectedIndex == index;
                  return GestureDetector(
                    onTap: () {
                      if (index == 1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const FriendPage()),
                        );
                      } else if (index == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfilePage()),
                        );
                      } else {
                        setState(() {
                          _selectedIndex = index;
                        });
                      }
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
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
