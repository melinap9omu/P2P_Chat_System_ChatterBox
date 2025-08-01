// import 'dart:convert';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// class WebRTCService {
//   RTCPeerConnection? _peerConnection;
//   WebSocketChannel? _channel;
//   RTCDataChannel? _dataChannel;
  
//   final Function(String)? onMessageReceived;
//   final Function(String)? onConnectionStateChanged;
//   final String userId;
  
//   WebRTCService({
//     required this.userId,
//     this.onMessageReceived,
//     this.onConnectionStateChanged,
//   });
  
//   Future<void> initialize() async {
//     try {
//       // Create peer connection
//       _peerConnection = await createPeerConnection({
//         'iceServers': [
//           {'urls': 'stun:stun.l.google.com:19302'}
//         ]
//       });
      
//       // Setup ICE candidate handler
//       _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
//         _sendSignalingMessage('ice-candidate', jsonEncode({
//           'candidate': candidate.candidate,
//           'sdpMid': candidate.sdpMid,
//           'sdpMLineIndex': candidate.sdpMLineIndex,
//         }), null);
//       };
      
//       // Setup connection state handler
//       _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
//         onConnectionStateChanged?.call(state.toString());
//       };
      
//       // Setup data channel for receiving
//       _peerConnection!.onDataChannel = (RTCDataChannel channel) {
//         channel.onMessage = (RTCDataChannelMessage message) {
//           onMessageReceived?.call(message.text);
//         };
//       };
      
//       // Connect to signaling server
//       _channel = WebSocketChannel.connect(
//         Uri.parse('ws://10.0.2.2:8080/ws/$userId'), // Android Emulator
//         // Uri.parse('ws://localhost:8080/ws/$userId'), // iOS Simulator
//       );
      
//       _channel!.stream.listen(
//         (message) {
//           try {
//             _handleSignalingMessage(jsonDecode(message));
//           } catch (e) {
//             print('Error handling signaling message: $e');
//           }
//         },
//         onError: (error) {
//           print('WebSocket error: $error');
//         },
//         onDone: () {
//           print('WebSocket connection closed');
//         },
//       );
      
//       print('WebRTC Service initialized for user $userId');
//     } catch (e) {
//       print('Error initializing WebRTC: $e');
//     }
//   }
  
//   Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
//     try {
//       switch (message['type']) {
//         case 'offer':
//           await _handleOffer(message['payload'], message['senderUserId']);
//           break;
//         case 'answer':
//           await _handleAnswer(message['payload']);
//           break;
//         case 'ice-candidate':
//           await _handleIceCandidate(message['payload']);
//           break;
//       }
//     } catch (e) {
//       print('Error handling signaling message: $e');
//     }
//   }
  
//   Future<void> startCall(int targetUserId) async {
//     try {
//       // Create data channel for sending
//       _dataChannel = await _peerConnection!.createDataChannel(
//         'messages',
//         RTCDataChannelInit()..ordered = true,
//       );
//       _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
//   print('Data channel state: $state');
//   if (state == RTCDataChannelState.RTCDataChannelOpen) {
//     print('Data channel is now open!');
//   }
// };

      
//       RTCSessionDescription offer = await _peerConnection!.createOffer();
//       await _peerConnection!.setLocalDescription(offer);
      
//       _sendSignalingMessage('offer', offer.sdp!, targetUserId);
//     } catch (e) {
//       print('Error starting call: $e');
//     }
//   }
  
//   Future<void> sendMessage(String message) async {
//     try {
//       if (_dataChannel != null && 
//           _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
//         _dataChannel!.send(RTCDataChannelMessage(message));
//         print('Message sent: $message');
//       } else {
//         print('Data channel not open. State: ${_dataChannel?.state}');
//       }
//     } catch (e) {
//       print('Error sending message: $e');
//     }
//   }
  
//   void _sendSignalingMessage(String type, String payload, int? targetUserId) {
//     try {
//       _channel!.sink.add(jsonEncode({
//         'type': type,
//         'payload': payload,
//         'targetUserId': targetUserId,
//       }));
//     } catch (e) {
//       print('Error sending signaling message: $e');
//     }
//   }
  
//   Future<void> _handleOffer(String sdp, int senderUserId) async {
//     try {
//       await _peerConnection!.setRemoteDescription(
//         RTCSessionDescription(sdp, 'offer'),
//       );
      
//       // Create data channel for this peer
//       _dataChannel = await _peerConnection!.createDataChannel(
//         'messages',
//         RTCDataChannelInit()..ordered = true,
//       );
      
//       _dataChannel!.onMessage = (RTCDataChannelMessage message) {
//         onMessageReceived?.call(message.text);
//       };
      
//       RTCSessionDescription answer = await _peerConnection!.createAnswer();
//       await _peerConnection!.setLocalDescription(answer);
      
//       _sendSignalingMessage('answer', answer.sdp!, senderUserId);
//     } catch (e) {
//       print('Error handling offer: $e');
//     }
//   }
  
//   Future<void> _handleAnswer(String sdp) async {
//     try {
//       await _peerConnection!.setRemoteDescription(
//         RTCSessionDescription(sdp, 'answer'),
//       );
//     } catch (e) {
//       print('Error handling answer: $e');
//     }
//   }
  
//   Future<void> _handleIceCandidate(String candidateJson) async {
//     try {
//       final candidateData = jsonDecode(candidateJson);
//       await _peerConnection!.addCandidate(RTCIceCandidate(
//         candidateData['candidate'],
//         candidateData['sdpMid'],
//         candidateData['sdpMLineIndex'],
//       ));
//     } catch (e) {
//       print('Error handling ICE candidate: $e');
//     }
//   }
  
//   void dispose() {
//     _dataChannel?.close();
//     _peerConnection?.dispose();
//     _channel?.sink.close();
//   }
// }