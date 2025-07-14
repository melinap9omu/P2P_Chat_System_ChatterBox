import 'package:flutter/material.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key});

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool isMicOn = true;
  bool isVideoOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Video Call', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Simulated video view (just an icon here)
          Center(
            child: Icon(
              Icons.videocam,
              size: 100,
              color: isVideoOn ? Colors.white : Colors.grey,
            ),
          ),

          // Bottom control buttons
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute mic
                  FloatingActionButton(
                    backgroundColor: Colors.grey[800],
                    onPressed: () {
                      setState(() {
                        isMicOn = !isMicOn;
                      });
                    },
                    child: Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      color: Colors.white,
                    ),
                  ),

                  // End call
                  FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: () {
                      Navigator.pop(context); // Go back to chat page
                    },
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),

                  // Video on / off
                  FloatingActionButton(
                    backgroundColor: Colors.grey[800],
                    onPressed: () {
                      setState(() {
                        isVideoOn = !isVideoOn;
                      });
                    },
                    child: Icon(
                      isVideoOn ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
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
