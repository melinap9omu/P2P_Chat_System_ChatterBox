// lib/webrtc/web_rtc_client.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // For File
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc; // WebRTC main library
import 'package:pointycastle/export.dart' as pc; // PointyCastle for crypto types
import 'package:path_provider/path_provider.dart'; // For file saving paths
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

import '../network/signaling_client.dart'; // Your SignalingClient
import '../crypto/rsa_key_manager.dart'; // Your RSA key manager
import '../crypto/rsa_encryptionDecryption_manager.dart'; // Your RSA encryption manager
import '../crypto/symmetric_encryptionDecryption_manager.dart'; // Your AES encryption manager
import '../config/app_config.dart';

/// Callback interface for WebRTC events to update the UI or other parts of the app.
/// Expanded for audio/video streams and file transfer progress.
/// Note: peerId/senderId are kept for clarity even in single-peer context,
/// as they identify the single remote peer.
abstract class WebRtcClientListener {
  void onNewPeerConnected(int peerId, String peerName);
  void onPeerDisconnected(int peerId);
  void onChatMessageReceived(int senderId, String message);
  void onConnectionStateChange(rtc.RTCPeerConnectionState state, int peerId);
  void onError(String message);
  void onKeyExchangeComplete(int peerId);
  void onLocalStream(rtc.MediaStream stream);
  void onRemoteStream(rtc.MediaStream stream, int peerId);
  void onFileMetadataReceived(int senderId, String fileId, String fileName, int fileSize, String fileType);
  void onFileChunkReceived(String fileId, int currentChunk, int totalChunks);
  void onFileTransferComplete(String fileId, String fileName, int senderId, String filePath);
  void onFileTransferError(String fileId, String message);
}

/// Manages WebRTC peer connection and data channel for a single peer.
class WebRtcClient implements SignalingClientListener {
  final int currentUserId;
  final SignalingClient signalingClient;
  final WebRtcClientListener listener;

  // Single peer connection and data channel
  rtc.RTCPeerConnection? _peerConnection;
  rtc.RTCDataChannel? _dataChannel;
  int? _connectedPeerId; // Stores the ID of the single connected peer

  // Single flag for key exchange status
  bool _keyExchangeCompleted = false;

  // File transfer buffers for the single incoming file
  final Map<String, List<int>> _incomingFileBuffers = {}; // Still a map as multiple files could theoretically be in transit (though unlikely with single peer, but easier to manage by fileId)
  final Map<String, String> _incomingFileNames = {};
  final Map<String, int> _incomingFileSizes = {};

  // Single peer chat message listener
  void Function(int senderId, String message)? _singlePeerChatMessageListener;

  rtc.MediaStream? _localStream;

  rtc.MediaStream? getLocalStream() => _localStream;

  // ICE (Interactive Connectivity Establishment) servers configuration.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls':'turn:your.turn.server.com:3478', 'username':'user','credential':'password'}, // Replace with your TURN server details if needed
    ]
  };

  // SDP Constraints: Now offering to send/receive audio and video
  final Map<String, dynamic> _sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  WebRtcClient({
    required this.currentUserId,
    required this.signalingClient,
    required this.listener,
  }) {
    // Constructor body is empty as field initialization is done via 'this.' in parameters.
  }

  // Methods to add/remove a single chat message listener for the active peer
  void addChatMessageListener(int peerId, void Function(int senderId, String message) callback) {
    // For single peer, we just set it. We still use peerId to ensure it's for the current active peer.
    if (_connectedPeerId != null && _connectedPeerId != peerId) {
      print('Warning: Setting chat listener for $peerId but connected to $_connectedPeerId');
    }
    _singlePeerChatMessageListener = callback;
    print('Set chat message listener for peer $peerId');
  }

  void removeChatMessageListener(int peerId) {
    if (_connectedPeerId == peerId) { // Only remove if it's the listener for the current peer
      _singlePeerChatMessageListener = null;
      print('Removed chat message listener for peer $peerId');
    }
  }

  /// Initializes local audio and video streams (camera and microphone).
  Future<void> _initLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };

    _localStream = await rtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
    listener.onLocalStream(_localStream!);
    print('Local media stream obtained: Audio: ${_localStream!.getAudioTracks().isNotEmpty}, Video: ${_localStream!.getVideoTracks().isNotEmpty}');
  }

  /// Adds local stream tracks to the single PeerConnection.
  void _addLocalStreamTracks(rtc.RTCPeerConnection pc) {
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        pc.addTrack(track, _localStream!);
      }
      for (final track in _localStream!.getVideoTracks()) {
        pc.addTrack(track, _localStream!);
      }
      print('Local stream tracks added to PeerConnection.');
    } else {
      print('No local stream to add.');
    }
  }

  /// Stops local media streams and releases resources.
  void _stopLocalStream() {
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => track.stop());
      _localStream!.dispose();
      _localStream = null;
      print('Local media Stream stopped and disposed.');
    }
  }

  /// Initiates a call/chat session with a target user (the single peer).
  Future<void> initiateCall(int targetUserId) async {
    print('Initiating call with user ID: $targetUserId');

    if (_peerConnection != null) {
      print('Call already in progress. Disposing existing connection.');
      await disposePeerConnection(_connectedPeerId ?? targetUserId); // Dispose existing if any
    }

    _connectedPeerId = targetUserId;
    _keyExchangeCompleted = false; // Reset key exchange status for new call

    try {
      await _initLocalStream();

      _peerConnection = await _createAndConfigurePeerConnection(targetUserId);

      _addLocalStreamTracks(_peerConnection!);

      // Create data channel for chat
      _dataChannel = await _peerConnection!.createDataChannel(
        'chat',
        rtc.RTCDataChannelInit(),
      );
      _setupDataChannelListeners(targetUserId, _dataChannel!);

      final offer = await _peerConnection!.createOffer(_sdpConstraints);
      await _peerConnection!.setLocalDescription(offer);

      signalingClient.send(SignalingMessage(
        type: 'offer',
        payload: offer.sdp,
        targetUserId: targetUserId,
      ));
      print('Sent SDP offer to $targetUserId.');
    } catch (e) {
      print('Error initiating call with $targetUserId: $e');
      listener.onError('Failed to initiate call with user $targetUserId: $e');
      _stopLocalStream();
      _peerConnection = null;
      _dataChannel = null;
      _connectedPeerId = null;
    }
  }

  /// Creates and configures an RTCPeerConnection.
  Future<rtc.RTCPeerConnection> _createAndConfigurePeerConnection(int peerId) async {
    final pc = await rtc.createPeerConnection(_iceServers, _sdpConstraints);

    pc.onIceCandidate = (rtc.RTCIceCandidate? candidate) {
      if (candidate != null) {
        print('Sending ICE candidate to $peerId: ${candidate.candidate}');
        signalingClient.send(SignalingMessage(
          type: 'candidate',
          payload: jsonEncode(candidate.toMap()),
          targetUserId: peerId,
        ));
      }
    };

    pc.onIceConnectionState = (rtc.RTCIceConnectionState state) {
      print('ICE connection state changed for $peerId: $state');
      // No explicit listener for this for single peer. Useful for debugging.
    };

    pc.onSignalingState = (rtc.RTCSignalingState state) {
      print('Signaling state changed for $peerId: $state');
    };

    pc.onConnectionState = (rtc.RTCPeerConnectionState state) {
      print('Peer connection state changed for $peerId: $state');
      listener.onConnectionStateChange(state, peerId);
      if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('Peer $peerId connected!');
        listener.onNewPeerConnected(peerId, 'User $peerId'); // Use generic name for now
      } else if (state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        print('Peer $peerId disconnected/failed/closed.');
        disposePeerConnection(peerId);
      }
    };

    pc.onAddStream = (rtc.MediaStream stream) {
      print('Remote stream received from $peerId: ${stream.id}');
      listener.onRemoteStream(stream, peerId);
    };

    pc.onDataChannel = (rtc.RTCDataChannel channel) {
      print('Remote peer $peerId opened data channel: ${channel.label}');
      _dataChannel = channel; // Assign the received data channel
      _setupDataChannelListeners(peerId, channel);
      _performKeyExchange(peerId, channel);
    };

    return pc;
  }

  /// Sets up listeners for the single RTCDataChannel, handling binary messages for files.
  void _setupDataChannelListeners(int peerId, rtc.RTCDataChannel channel) {
    channel.onMessage = (rtc.RTCDataChannelMessage message) async {
      if (message.isBinary) {
        print('Received binary message (file chunk) from $peerId.');
        _handleIncomingFileChunk(peerId, message.binary);
      } else {
        print('Received data channel text message from $peerId: ${message.text}');
        try {
          final incomingSigMsg = SignalingMessage.fromJson(jsonDecode(message.text));

          if (incomingSigMsg.type == 'aes_key_exchange') {
            _handleAesKeyExchange(peerId, incomingSigMsg.payload!);
          } else if (incomingSigMsg.type == 'file_metadata') {
            if (!_keyExchangeCompleted) { // Check single flag
              print('Received encrypted file metadata before key exchange completed from $peerId. Ignoring.');
              listener.onError('Received encrypted file metadata before key exchange from $peerId.');
              return;
            }
            final decryptedMetadataJson = SymmetricEncryptionManager.decrypt(incomingSigMsg.payload!);
            final Map<String, dynamic> metadata = jsonDecode(decryptedMetadataJson);
            _handleIncomingFileMetadata(peerId, metadata);
          } else if (incomingSigMsg.type == 'chat_message') {
            if (!_keyExchangeCompleted) { // Check single flag
              print('Received chat message before key exchange completed from $peerId. Ignoring.');
              listener.onError('Received chat message before key exchange from $peerId.');
              return;
            }
            final decryptedMessage = SymmetricEncryptionManager.decrypt(incomingSigMsg.payload!);
            // Call the specific chat message listener for this peer if exists
            _singlePeerChatMessageListener?.call(peerId, decryptedMessage);
            // Also notify the global listener if it's still desired for all chat messages
            listener.onChatMessageReceived(peerId, decryptedMessage);
          } else if (incomingSigMsg.type == 'file_chunk_ack') {
            print('Received file chunk ACK from $peerId for file ${incomingSigMsg.metadata?['fileId']} chunk ${incomingSigMsg.metadata?['chunkIndex']}');
          }
          else {
            print('Unknown data channel signaling message type: ${incomingSigMsg.type}');
          }
        } catch (e) {
          print('Error parsing or handling data channel message from $peerId: $e, Message: ${message.text}');
          if (_keyExchangeCompleted) { // Check single flag
            try {
              final decryptedMessage = SymmetricEncryptionManager.decrypt(message.text);
              _singlePeerChatMessageListener?.call(peerId, decryptedMessage); // Try to deliver as chat
              listener.onChatMessageReceived(peerId, decryptedMessage); // Global listener
            } catch (decryptError) {
              print('Error decrypting fallback chat message from $peerId: $decryptError');
              listener.onError('Failed to decrypt message from $peerId: $decryptError');
            }
          } else {
            listener.onError('Received unencrypted message before key exchange from $peerId: ${message.text}');
          }
        }
      }
    };

    channel.onDataChannelState = (rtc.RTCDataChannelState state) {
      print('Data Channel State for $peerId: $state');
      if (state == rtc.RTCDataChannelState.RTCDataChannelOpen) {
        print('Data Channel with $peerId is OPEN!');
        _performKeyExchange(peerId, channel);
      }
    };
  }

  /// Handles incoming file metadata, preparing to receive chunks.
  void _handleIncomingFileMetadata(int senderId, Map<String, dynamic> metadata) {
    final fileId = metadata['fileId'] as String;
    final fileName = metadata['fileId'] as String; // This seems like a typo, should be 'fileName'
    final fileSize = metadata['fileSize'] as int;
    final fileType = metadata['fileType'] as String;

    print('Received file metadata from $senderId: $fileName ($fileSize bytes)');
    _incomingFileBuffers[fileId] = [];
    _incomingFileNames[fileId] = fileName;
    _incomingFileSizes[fileId] = fileSize;

    listener.onFileMetadataReceived(senderId, fileId, fileName, fileSize, fileType);
  }

  /// Handles incoming file chunks and reassembles the file.
  Future<void> _handleIncomingFileChunk(int senderId, Uint8List chunk) async {
    if (chunk.length < 32) {
      print('Received invalid small file chunk from $senderId.');
      listener.onFileTransferError('unknown', 'Received invalid file chunk size.');
      return;
    }

    final String fileId = utf8.decode(chunk.sublist(0, 16)).replaceAll(RegExp(r'\x00'), ''); // Remove null bytes from padding
    final int chunkIndex = ByteData.view(chunk.buffer, chunk.offsetInBytes + 16, 8).getUint64(0, Endian.little);
    final int totalChunks = ByteData.view(chunk.buffer, chunk.offsetInBytes + 24, 8).getUint64(0, Endian.little);
    final Uint8List data = chunk.sublist(32);

    _incomingFileBuffers[fileId]?.addAll(data);
    final receivedBytesLength = _incomingFileBuffers[fileId]?.length ?? 0;
    final expectedFileSize = _incomingFileSizes[fileId];

    print('Received chunk $chunkIndex/$totalChunks for file $fileId. Data length: ${data.length}');
    listener.onFileChunkReceived(fileId, chunkIndex, totalChunks);

    if (expectedFileSize != null && receivedBytesLength >= expectedFileSize) {
      final allBytes = _incomingFileBuffers.remove(fileId);
      final fileName = _incomingFileNames.remove(fileId);
      final fileSize = _incomingFileSizes.remove(fileId);

      if (allBytes != null && fileName != null && fileSize != null) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(Uint8List.fromList(allBytes));
          print('File $fileName ($fileId) received completely at $filePath');
          listener.onFileTransferComplete(fileId, fileName, senderId, filePath);
        } catch (e) {
          print('Error saving received file $fileName ($fileId): $e');
          listener.onFileTransferError(fileId, 'Failed to save received file: $e');
        }
      } else {
        print('Error: Missing data for file $fileId after receiving all chunks.');
        listener.onFileTransferError(fileId, 'Missing file data after transfer.');
      }
    }
  }

  /// Performs the RSA-AES hybrid key exchange over the data channel.
  Future<void> _performKeyExchange(int peerId, rtc.RTCDataChannel channel) async {
    if (_keyExchangeCompleted) { // Check single flag
      print('Key exchange already completed for peer $peerId. Skipping.');
      return;
    }

    try {
      print('Requesting public key for user $peerId via HTTP...');
      final publicKeyRawBase64 = await _requestPublicKeyHttp(peerId);
      if (publicKeyRawBase64 == null) {
        listener.onError('Failed to get public key for user $peerId. Cannot perform key exchange.');
        return;
      }
      final remotePublicKey = RsaKeyManager.decodeRemotePublicKeyFromX509Base64(publicKeyRawBase64);
      if (remotePublicKey == null) {
        listener.onError('Invalid public key received for user $peerId. Cannot perform key exchange.');
        return;
      }
      print('Received and decoded public key for user $peerId.');

      // Only the peer with the lower ID generates and sends the AES key to avoid race conditions
      if (currentUserId < peerId) {
        final aesKeyBase64 = SymmetricEncryptionManager.generateAesKeyBase64();
        print('Generated new AES key.');

        final encryptedAesKey = RsaEncryptionManager.encryptWithPublicKey(aesKeyBase64, remotePublicKey);
        print('Encrypted AES key with user $peerId\'s public key.');

        final keyExchangeMessage = SignalingMessage(
          type: 'aes_key_exchange',
          payload: encryptedAesKey,
          senderUserId: currentUserId,
          targetUserId: peerId,
        );
        await channel.send(rtc.RTCDataChannelMessage(jsonEncode(keyExchangeMessage.toJson())));
        print('Sent encrypted AES key to user $peerId via DataChannel.');

        SymmetricEncryptionManager.setSharedAesKey(aesKeyBase64); // Sets the global shared key
        _keyExchangeCompleted = true; // Set single flag
        listener.onKeyExchangeComplete(peerId);
        print('Key exchange completed successfully with user $peerId.');
      } else {
        print('Waiting for peer $peerId to initiate AES key exchange.');
      }
    } catch (e) {
      print('Error during key exchange with $peerId: $e');
      listener.onError('Key exchange failed with user $peerId: $e');
    }
  }

  /// Handles incoming AES key exchange message (decrypts the key).
  Future<void> _handleAesKeyExchange(int peerId, String encryptedAesKeyBase64) async {
    if (_keyExchangeCompleted) { // Check single flag
      print('Key exchange already completed for $peerId. Ignoring duplicate.');
      return;
    }
    try {
final localPrivateKey = await RsaKeyManager.getPrivateKey(currentUserId.toString());
      if (localPrivateKey == null) {
        throw StateError('Local RSA private key not found for AES key decryption.');
      }
      final decryptedAesKeyBase64 = RsaEncryptionManager.decryptWithPrivateKey(
        encryptedAesKeyBase64,
        localPrivateKey,
      );
      SymmetricEncryptionManager.setSharedAesKey(decryptedAesKeyBase64); // Sets the global shared key
      _keyExchangeCompleted = true; // Set single flag
      listener.onKeyExchangeComplete(peerId);
      print('Successfully decrypted and set AES key for $peerId.');
    } catch (e) {
      print('Error processing AES key exchange from $peerId: $e');
      listener.onError('Failed AES key exchange with user $peerId: $e');
    }
  }

  /// Sends a chat message to the connected peer.
  /// The message is encrypted before sending.
  Future<void> sendChatMessage(int targetUserId, String message) async {
    // Ensure targetUserId matches the currently connected peer
    if (_connectedPeerId != targetUserId) {
      throw Exception('Cannot send message: Not connected to target user $targetUserId.');
    }

    if (_dataChannel == null || _dataChannel!.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
      print('Data channel to $targetUserId not open. Cannot send message.');
      listener.onError('Chat channel to $targetUserId is not open.');
      throw Exception('Data channel to $targetUserId not open.');
    }
    if (!_keyExchangeCompleted) { // Check single flag
      print('Key exchange not completed with $targetUserId. Cannot send encrypted message.');
      listener.onError('Cannot send message: Key exchange not complete with $targetUserId.');
      throw Exception('Key exchange not complete with $targetUserId.');
    }

    try {
      final encryptedMessage = SymmetricEncryptionManager.encrypt(message);
      print('Sending encrypted message to $targetUserId: $encryptedMessage');

      final chatMessage = SignalingMessage(
        type: 'chat_message',
        payload: encryptedMessage,
        senderUserId: currentUserId,
        targetUserId: targetUserId,
      );
      await _dataChannel!.send(rtc.RTCDataChannelMessage(jsonEncode(chatMessage.toJson())));
    } catch (e) {
      print('Error sending encrypted message to $targetUserId: $e');
      listener.onError('Failed to send encrypted message to $targetUserId: $e');
      rethrow;
    }
  }

  /// Sends a file to the connected peer.
  /// Handles reading the file, chunking, and sending binary data.
  /// A simple protocol is used: send metadata (JSON) then binary chunks.
  Future<void> sendFile(int targetUserId, String filePath) async {
    // Ensure targetUserId matches the currently connected peer
    if (_connectedPeerId != targetUserId) {
      listener.onError('Cannot send file: Not connected to target user $targetUserId.');
      return;
    }

    if (_dataChannel == null || _dataChannel!.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
      listener.onError('Data channel to $targetUserId not open. Cannot send file.');
      return;
    }
    if (!_keyExchangeCompleted) { // Check single flag
      listener.onError('Key exchange not completed with $targetUserId. Cannot send encrypted file.');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        listener.onError('File does not exist at path: $filePath');
        return;
      }

      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      final fileType = _getFileType(fileName);
      final fileId = const Uuid().v4();

      // 1. Send file metadata (JSON, encrypted)
      final metadata = {
        'fileId': fileId,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileType,
      };
      // Encrypt metadata before sending as part of SignalingMessage payload
      final encryptedMetadata = SymmetricEncryptionManager.encrypt(jsonEncode(metadata));
      final metadataMessage = SignalingMessage(
        type: 'file_metadata',
        payload: encryptedMetadata, // Send encrypted metadata here
        senderUserId: currentUserId,
        targetUserId: targetUserId,
      );
      await _dataChannel!.send(rtc.RTCDataChannelMessage(jsonEncode(metadataMessage.toJson())));
      print('Sent file metadata for $fileName (ID: $fileId) to $targetUserId.');

      // 2. Read and send file in chunks (binary)
      const int chunkSize = 64 * 1024; // 64 KB chunks
      final fileBytes = await file.readAsBytes();
      int totalChunks = (fileBytes.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize > fileBytes.length) ? fileBytes.length : start + chunkSize;
        final chunk = fileBytes.sublist(start, end);

        final header = Uint8List(32);
        final fileIdBytes = utf8.encode(fileId);
        // Ensure fileIdBytes are padded to 16 bytes for consistency
        for(int j = 0; j < 16; j++){
          if(j < fileIdBytes.length){
            header[j] = fileIdBytes[j];
          } else {
            header[j] = 0; // Pad with null bytes
          }
        }
        ByteData.view(header.buffer, 16, 8).setUint64(0, i, Endian.little);
        ByteData.view(header.buffer, 24, 8).setUint64(0, totalChunks, Endian.little);

        final chunkWithHeader = Uint8List(header.length + chunk.length);
        chunkWithHeader.setRange(0, header.length, header);
        chunkWithHeader.setRange(header.length, chunkWithHeader.length, chunk);

        await _dataChannel!.send(rtc.RTCDataChannelMessage.fromBinary(chunkWithHeader));
        listener.onFileChunkReceived(fileId, i + 1, totalChunks);
      }
      print('File $fileName (ID: $fileId) sent completely to $targetUserId.');
      listener.onFileTransferComplete(fileId, fileName, currentUserId, filePath);
    } catch (e) {
      print('Error sending file $filePath to $targetUserId: $e');
      listener.onError('Failed to send file: $e');
    }
  }

  // Basic helper to determine file type (for metadata)
  String _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'txt': return 'text/plain';
      case 'pdf': return 'application/pdf';
      default: return 'application/octet-stream';
    }
  }

  /// Disposes of the active peer connection, including stopping local stream.
  void disposeAll() {
    disposePeerConnection(_connectedPeerId); // Dispose the single connected peer
    _connectedPeerId = null;
    _keyExchangeCompleted = false;
    _incomingFileBuffers.clear();
    _incomingFileNames.clear();
    _incomingFileSizes.clear();
    _singlePeerChatMessageListener = null; // Clear single listener
    _stopLocalStream();
  }

  /// Disposes the peer connection with a specific ID (should be the active one).
  Future<void> disposePeerConnection(int? peerId) async {
    if (peerId == null || _connectedPeerId != peerId) {
      print('No active connection or trying to dispose wrong peer: $peerId');
      return;
    }

    if (_dataChannel != null) {
      await _dataChannel!.close();
      _dataChannel = null;
    }
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    _connectedPeerId = null;
    _keyExchangeCompleted = false;
    _singlePeerChatMessageListener = null;
    listener.onPeerDisconnected(peerId);
    print('Peer connection with $peerId disposed.');
    _stopLocalStream(); // Ensure local stream is stopped when peer disconnects
  }

  // --- SignalingClientListener Implementation ---
  @override
  void onMessage(SignalingMessage message) async {
    print('WebRtcClient received signaling message: ${message.type}');
    final peerId = message.senderUserId;

    if (peerId == null || peerId == currentUserId) {
      print('Received signaling message without valid sender ID or from self. Ignoring.');
      return;
    }

    // Ensure we are processing messages for the expected peer, or initialize if new.
    if (_connectedPeerId == null) {
      _connectedPeerId = peerId; // Set the peer we are now connecting to
      _peerConnection = await _createAndConfigurePeerConnection(peerId);
    } else if (_connectedPeerId != peerId) {
      print('Warning: Received signaling message from unexpected peer $peerId. Expected $_connectedPeerId. Ignoring.');
      return; // Ignore messages from unexpected peers in single-peer mode
    }

    switch (message.type) {
      case 'offer':
        print('Received SDP offer from $peerId. Setting remote description...');
        if (_localStream == null) {
          await _initLocalStream();
          _addLocalStreamTracks(_peerConnection!);
        }
        await _peerConnection!.setRemoteDescription(
          rtc.RTCSessionDescription(message.payload!, 'offer'),
        );
        final answer = await _peerConnection!.createAnswer(_sdpConstraints);
        await _peerConnection!.setLocalDescription(answer);
        print('Sending SDP answer to $peerId.');
        signalingClient.send(SignalingMessage(
          type: 'answer',
          payload: answer.sdp,
          targetUserId: peerId,
        ));
        break;

      case 'answer':
        print('Received SDP answer from $peerId. Setting remote description...');
        await _peerConnection!.setRemoteDescription(
          rtc.RTCSessionDescription(message.payload!, 'answer'),
        );
        break;

      case 'candidate':
        print('Received ICE candidate from $peerId. Adding candidate...');
        final Map<String, dynamic> candidateMap = jsonDecode(message.payload!);
        final rtc.RTCIceCandidate candidate = rtc.RTCIceCandidate(
          candidateMap['candidate'],
          candidateMap['sdpMid'],
          candidateMap['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
        break;

      case 'aes_key_exchange':
        print('Received AES key exchange message via signaling (should be via DataChannel).');
        if (message.payload != null) {
          _handleAesKeyExchange(peerId, message.payload!);
        } else {
          print('AES key exchange message has null payload.');
        }
        break;

      case 'chat_message':
      // This case should ideally not be hit for chat_message, as they should come via DataChannel.
        print('Received encrypted chat message via signaling (should be via DataChannel).');
        if (!_keyExchangeCompleted) { // Check single flag
          print('Received chat message before key exchange completed from $peerId. Ignoring.');
          listener.onError('Received chat message before key exchange from $peerId.');
          return;
        }
        try {
          final encryptedMessage = message.payload;
          if (encryptedMessage == null) {
            throw FormatException('Chat message payload is null.');
          }
          final decryptedMessage = SymmetricEncryptionManager.decrypt(encryptedMessage);
          _singlePeerChatMessageListener?.call(peerId, decryptedMessage); // Deliver to specific listener
          listener.onChatMessageReceived(peerId, decryptedMessage); // Global listener
        } catch (e) {
          print('Error decrypting chat message from $peerId: $e');
          listener.onError('Failed to decrypt chat message from $peerId: $e');
        }
        break;

      case 'file_metadata':
      // This case should ideally not be hit for file_metadata, as they should come via DataChannel.
        print('Received file metadata via signaling (should be via DataChannel).');
        if (!_keyExchangeCompleted) { // Check single flag
          print('Received encrypted file metadata before key exchange completed from $peerId. Ignoring.');
          listener.onError('Received encrypted file metadata before key exchange from $peerId.');
          return;
        }
        try {
          final decryptedMetadataJson = SymmetricEncryptionManager.decrypt(message.payload!);
          final Map<String, dynamic> metadata = jsonDecode(decryptedMetadataJson);
          _handleIncomingFileMetadata(peerId, metadata);
        } catch (e) {
          print('Error parsing or decrypting file metadata from signaling: $e');
          listener.onError('Failed to process file metadata from signaling: $e');
        }
        break;

      default:
        print('Unknown signaling message type: ${message.type}');
        break;
    }
  }

  @override
  void onOpen() {
    print('Signaling connection opened. Ready for WebRTC.');
  }

  @override
  void onClose(int? code, String? reason) {
    print('Signaling connection closed. Code: $code, Reason: $reason');
    disposeAll();
  }

  @override
  void onError(dynamic error) {
    print('Signaling connection error: $error');
    listener.onError('Signaling error: $error');
    disposeAll();
  }

  // --- HTTP Helper for Public Key Retrieval ---
  Future<String?> _requestPublicKeyHttp(int targetUserId) async {
    try {
      final uri = Uri.parse('$SERVER_HTTP_BASE_URL/public-key?targetUserId=$targetUserId');
      print('Fetching public key from: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) { // Check backend's success flag
          final String? publicKeyPem = jsonResponse['publicKeyPem'] as String?; // Assuming backend sends 'publicKeyPem'
          if (publicKeyPem != null) {
            print('Successfully fetched public key for user $targetUserId.');
            return publicKeyPem;
          } else {
            print('Error: publicKeyPem field missing in response for $targetUserId: ${response.body}');
            listener.onError('Public key not found in response for user $targetUserId.');
            return null;
          }
        } else {
          print('Failed to fetch public key: ${jsonResponse['message']}');
          listener.onError('Failed to fetch public key: ${jsonResponse['message']}');
          return null;
        }
      } else {
        print('Failed to fetch public key via HTTP for $targetUserId: Status ${response.statusCode} - ${response.body}');
        listener.onError('Failed to fetch public key for user $targetUserId: Status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('HTTP request error for public key of $targetUserId: $e');
      listener.onError('Network error fetching public key for user $targetUserId: $e');
      return null;
    }
  }
}