// lib/webrtc/web_rtc_client.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // For File
import 'dart:async'; // For Completer

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc; // WebRTC main library
import 'package:pointycastle/export.dart' as pc; // PointyCastle for crypto types
import 'package:path_provider/path_provider.dart'; // For file saving paths
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

import '../network/signaling_client.dart'; // Your SignalingClient
import '../crypto/rsa_key_manager.dart'; // Your RSA key manager
import '../crypto/rsa_encryptionDecryption_manager.dart'; // Your RSA encryption manager
import '../crypto/symmetric_encryptionDecryption_manager.dart'; // Your AES encryption manager
import '../config/app_config.dart';
import '../services/API_service.dart';

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
  // Removed: void onLocalStream(rtc.MediaStream stream);
  // Removed: void onRemoteStream(rtc.MediaStream stream, int peerId);
  void onKeyExchangeComplete(int peerId);
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
  final ApiService _apiService;
  final Dio _dio;

  bool _isSignalingConnected = false;
  DateTime? _lastSignalingMessage;

  // Connection state flags and counters
  bool _isConnected = false;
  bool _isDataChannelOpen = false;
  int _reconnectAttempts = 0;
  static const int MAX_RECONNECT_ATTEMPTS = 5;

  // Single peer connection and data channel
  rtc.RTCPeerConnection? _peerConnection;
  rtc.RTCDataChannel? _dataChannel;
  int? _connectedPeerId; // Stores the ID of the single connected peer

  // Single flag for key exchange status
  bool _keyExchangeCompleted = false;
  bool _keyExchangeInProgress = false;

  Completer<void>? _keyExchangeCompleter;

  final Map<int, Completer<void>> _keyExchangeCompleters = {};
  final Map<int, bool> _keyExchangeStates = {};
  final Map<int, bool> _keyExchangeInProgressStates = {};


  // File transfer buffers for the single incoming file
  final Map<String, List<int>> _incomingFileBuffers = {};
  final Map<String, String> _incomingFileNames = {};
  final Map<String, int> _incomingFileSizes = {};

  // Single peer chat message listener
  void Function(int senderId, String message)? _singlePeerChatMessageListener;
  // ICE (Interactive Connectivity Establishment) servers configuration.
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      // Alternative STUN servers for better reliability
      {'urls': 'stun:stun.stunprotocol.org:3478'},
      {'urls': 'stun:stun.services.mozilla.com'},
    ]
  };


  static const Duration ICE_GATHERING_TIMEOUT = Duration(seconds: 10);
  static const Duration DATA_CHANNEL_TIMEOUT = Duration(seconds: 15);
  static const Duration KEY_EXCHANGE_TIMEOUT = Duration(seconds: 30);
  // SDP Constraints: Now offering to send/receive audio and video
  final Map<String, dynamic> _sdpConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false, // Changed to false
      'OfferToReceiveVideo': false, // Changed to false
    },
    'optional': [],
  };

  WebRtcClient({
    required this.currentUserId,
    required this.signalingClient,
    required this.listener,
    required ApiService apiService,
  })  : _apiService = apiService,
        _dio = apiService.dio {
    // Constructor body
  }

  // Methods to add/remove a single chat message listener for the active peer
  void addChatMessageListener(int peerId, void Function(int senderId, String message) callback) {
    final connectedPeerId = _connectedPeerId;
    if (connectedPeerId != null && connectedPeerId != peerId) {
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


  /// Initiates a call/chat session with a target user (the single peer).
  Future<void> initiateCall(int targetUserId) async {
    print('Initiating call with user ID: $targetUserId');

    final existingPeerConnection = _peerConnection;
    if (existingPeerConnection != null) {
      print('Call already in progress. Disposing existing connection.');
      // Ensure that _connectedPeerId is non-null before passing it

      final connectedPeerId = _connectedPeerId;
      if (connectedPeerId != null) {
        await disposePeerConnection(connectedPeerId); // Dispose existing if any
      } else {
        await disposePeerConnection(targetUserId); // If _connectedPeerId is null, use targetUserId for disposal
      }
    }

    _connectedPeerId = targetUserId;
    _resetConnectionState();// Reset key exchange status for new call

    try {

      _peerConnection = await _createAndConfigurePeerConnection(targetUserId);

      final peerConnection = _peerConnection;
      if (peerConnection == null){
        throw Exception ('Failed to create peer connection');

      }

      // Create data channel for chat
     try{ _dataChannel = await peerConnection.createDataChannel(
        'chat',
        rtc.RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 3,
      );
      }catch(e){
        print('Unable to create DataChannel');
     }
      final dataChannel = _dataChannel;
      print('DataChannel:${dataChannel}');
      if (dataChannel != null) {
        _setupDataChannelListeners(targetUserId, dataChannel);
      }
      final offer = await peerConnection.createOffer(_sdpConstraints);
      await peerConnection.setLocalDescription(offer);

      signalingClient.send(SignalingMessage(
        type: 'offer',
        payload: offer.sdp,
        senderUserId: currentUserId, // Add this line
        targetUserId: targetUserId,
      ));
      print('Sent SDP offer to $targetUserId.');
    } catch (e) {
      print('Error initiating call with $targetUserId: $e');
      listener.onError('Failed to initiate call with user $targetUserId: $e');
      _cleanup();
    }
  }

  /// Reset connection state for new connection
  void _resetConnectionState() {
    _isConnected = false;
    _isDataChannelOpen = false;
    _keyExchangeCompleted = false;
    _keyExchangeInProgress = false;
    final completer = _keyExchangeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _keyExchangeCompleter = null;
    _reconnectAttempts = 0;
  }

  /// Creates and configures an RTCPeerConnection.
  Future<rtc.RTCPeerConnection> _createAndConfigurePeerConnection(int peerId) async {
    print('Creating peer connection for $peerId with ICE servers: ${_iceServers['iceServers']}');

    final pc = await rtc.createPeerConnection(_iceServers, _sdpConstraints);

    pc.onIceGatheringState = (rtc.RTCIceGatheringState state) {
      print('ICE gathering state for $peerId: $state');

      switch (state) {
        case rtc.RTCIceGatheringState.RTCIceGatheringStateComplete:
          print('ICE gathering completed for $peerId');
          break;
        case rtc.RTCIceGatheringState.RTCIceGatheringStateGathering:
          print('ICE gathering in progress for $peerId');
          break;
        default:
          break;
      }
    };

    pc.onIceCandidate = (rtc.RTCIceCandidate? candidate) {
      if (candidate != null) {
        print('Generated ICE candidate for $peerId: ${candidate.candidate}');
        print('Candidate type: ${_getIceCandidateType(candidate.candidate ?? '')}');

        signalingClient.send(SignalingMessage(
          type: 'candidate',
          payload: jsonEncode(candidate.toMap()),
          senderUserId: currentUserId, // Add this line
          targetUserId: peerId,
        ));
      } else {
        print('ICE candidate gathering finished for $peerId');
      }
    };

    pc.onIceConnectionState = (rtc.RTCIceConnectionState state) {
      print('ICE connection state changed for $peerId: $state');

      switch (state) {
        case rtc.RTCIceConnectionState.RTCIceConnectionStateConnected:
        case rtc.RTCIceConnectionState.RTCIceConnectionStateCompleted:
          print('ICE connection established for $peerId');
          break;
        case rtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          print('ICE connection disconnected for $peerId');
          _handleReconnection(peerId);
          break;
        case rtc.RTCIceConnectionState.RTCIceConnectionStateFailed:
          print('ICE connection failed for $peerId');
          _handleConnectionFailure(peerId);
          break;
        default:
          break;
      }
    };

    pc.onSignalingState = (rtc.RTCSignalingState state) {
      print('Signaling state changed for $peerId: $state');
    };

    pc.onConnectionState = (rtc.RTCPeerConnectionState state) {
      print('Peer connection state changed for $peerId: $state');
      listener.onConnectionStateChange(state, peerId);

      switch (state) {
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          print('Peer $peerId connected!');
          _isConnected = true;
          listener.onNewPeerConnected(peerId, 'User $peerId');
          break;
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          print('Peer $peerId disconnected.');
          _isConnected = false;
          break;
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          print('Peer $peerId connection failed.');
          _handleConnectionFailure(peerId);
          break;
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          print('Peer $peerId connection closed.');
          disposePeerConnection(peerId);
          break;
        default:
          break;
      }
    };



    pc.onDataChannel = (rtc.RTCDataChannel channel) {
      print('Remote peer $peerId opened data channel: ${channel.label}');
      _dataChannel = channel; // Assign the received data channel
      _setupDataChannelListeners(peerId, channel);
    };

    return pc;
  }

  String _getIceCandidateType(String candidate) {
    if (candidate.contains('typ host')) return 'host';
    if (candidate.contains('typ srflx')) return 'server-reflexive';
    if (candidate.contains('typ prflx')) return 'peer-relfexive';
    if (candidate.contains('typ relay')) return 'relay';
    return 'unknown';
  }

  Future<bool> testIceConnectivity() async {
    try {
      print('Testing ICE connectivity ...');

      final testPc = await rtc.createPeerConnection(_iceServers, _sdpConstraints);

      bool hasValidCandidates = false;

      testPc.onIceCandidate = (rtc.RTCIceCandidate? candidate) {
        if (candidate != null) {
          hasValidCandidates = true;
          final candidateStr = candidate.candidate;
          if (candidateStr!= null) {
            print('Test ICE candidate generated: ${_getIceCandidateType(candidateStr)}');
          }
        }
      };

      final offer = await testPc.createOffer(_sdpConstraints);
      await testPc.setLocalDescription(offer);

      await Future.delayed(Duration(seconds: 5));

      await testPc.close();

      print('ICE connectivity test completed. Has valid candidate: $hasValidCandidates');
      return hasValidCandidates;
    } catch (e) {
      print('ICE connectivity test failed: $e');
      return false;
    }
  }

  /// Sets up listeners for the single RTCDataChannel, handling binary messages for files.
  void _setupDataChannelListeners(int peerId, rtc.RTCDataChannel channel) {
    channel.onDataChannelState = (rtc.RTCDataChannelState state) {
      print('Data Channel State for $peerId: $state');

      switch (state) {
        case rtc.RTCDataChannelState.RTCDataChannelOpen:
          _isDataChannelOpen = true;
          print('Data Channel with $peerId is OPEN!');
          // Use enhanced key exchange with proper timing
          Future.delayed(Duration(milliseconds: 100), () {
            _initiateKeyExchange(peerId, channel);
          });
          break;
        case rtc.RTCDataChannelState.RTCDataChannelClosed:
        case rtc.RTCDataChannelState.RTCDataChannelClosing:
          _isDataChannelOpen = false;
          _keyExchangeStates[peerId] = false;
          _keyExchangeInProgressStates[peerId] = false;
          print('Data Channel with $peerId closed/closing');
          break;
        default:
          _isDataChannelOpen = false;
          break;
      }
    };

    channel.onMessage = (rtc.RTCDataChannelMessage message) async {
      if (message.isBinary) {
        print('Received binary message (file chunk) from $peerId.');
        await _handleIncomingFileChunk(peerId, message.binary);
      } else {
        print('Received data channel text message from $peerId: ${message.text}');
        await _handleDataChannelMessage(peerId, message.text);
      }
    };
  }

  Future<void> _handleDataChannelMessage(int peerId, String messageText) async {
    try {
      final incomingSigMsg = SignalingMessage.fromJson(jsonDecode(messageText));
      switch (incomingSigMsg.type) {
        case 'aes_key_exchange':
          final payload = incomingSigMsg.payload;
          if (payload == null) { // Add null check for payload
            print('Received AES key exchange message with null payload from $peerId. Ignoring.');
            listener.onError('Received AES key exchange message with null payload from $peerId.');
            return;
          }
          await _handleAesKeyExchange(peerId, payload);
          break;
        case 'file_metadata':
          if (_keyExchangeStates[peerId] != true) {
            print('Received encrypted file metadata before key exchange completed from $peerId. Ignoring.');
            listener.onError('Received encrypted file metadata before key exchange from $peerId.');
            return;
          }
          final payload = incomingSigMsg.payload;
          if (payload == null) { // Add null check for payload
            print('Received file metadata message with null payload from $peerId. Ignoring.');
            listener.onError('Received file metadata message with null payload from $peerId.');
            return;
          }
          final decryptedMetadataJson = SymmetricEncryptionManager.decrypt(payload);
          final Map<String, dynamic> metadata = jsonDecode(decryptedMetadataJson);
          _handleIncomingFileMetadata(peerId, metadata);
          break;
        case 'chat_message':
          if (_keyExchangeStates[peerId] != true) {
            print('Received chat message before key exchange completed from $peerId. Ignoring.');
            listener.onError('Received chat message before key exchange from $peerId.');
            return;
          }
          final payload = incomingSigMsg.payload;
          if (payload == null) { // Add null check for payload
            print('Received chat message with null payload from $peerId. Ignoring.');
            listener.onError('Received chat message with null payload from $peerId.');
            return;
          }
          final decryptedMessage = SymmetricEncryptionManager.decrypt(payload);
          final chatListener =  _singlePeerChatMessageListener;
          if (chatListener!= null){
            chatListener(peerId, decryptedMessage);
          }
          listener.onChatMessageReceived(peerId, decryptedMessage);
          break;
        default:
          print('Unknown data channel signaling message type: ${incomingSigMsg.type}');
          break;
      }
    } catch (e) {
      print('Error parsing or handling data channel message from $peerId: $e');
      listener.onError('Failed to process message from $peerId: $e');
    }
  }

  void _handleIncomingFileMetadata(int senderId, Map<String, dynamic> metadata) {
    final fileId = metadata['fileId'] as String;
    final fileName = metadata['fileName'] as String;
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

    final fileBuffer =  _incomingFileBuffers[fileId];
    if (fileBuffer != null ){
      fileBuffer.addAll(data);
    }
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

  Future<void> _initiateKeyExchange(int peerId, rtc.RTCDataChannel channel) async {
    if (_keyExchangeInProgressStates[peerId] == true) {
      print('Key exchange already in progress for peer $peerId . Waiting...');
      final completer = _keyExchangeCompleters[peerId];
      if (completer != null) {
        await completer.future;
      }
      return;
    }

    if (_keyExchangeStates[peerId] == true) {
      print('Key exchange already completed for peer $peerId. Skipping.');
      return;
    }

    _keyExchangeInProgressStates[peerId] = true;
    _keyExchangeCompleters[peerId] = Completer<void>();

    try {
      await Future.delayed(Duration(milliseconds: 500));

      if (channel.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
        throw Exception('Data channel not open during key exchange initiation');
      }

      await _performKeyExchange(peerId, channel).timeout(KEY_EXCHANGE_TIMEOUT);
    } catch (e) {
      print('Key exchange failed for $peerId: $e');
      final completer =  _keyExchangeCompleters[peerId];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }

      listener.onError('Key exchange failed with user $peerId: $e');

    } finally {
      _keyExchangeInProgressStates[peerId] = false;
    }
  }
// Enhanced debugging for the key exchange process
  Future<void> _performKeyExchange(int peerId, rtc.RTCDataChannel channel) async {
    try {
      print('=== ENHANCED KEY EXCHANGE DEBUG START ===');
      print('Starting enhanced key exchange with peer $peerId...');
      print('Current user ID: $currentUserId');

      // Request public key with retry logic
      final publicKeyRawBase64 = await _requestPublicKeyWithRetry(peerId);
      print("DEBUG: Raw format of public key from backend: ${publicKeyRawBase64?.substring(0, 100)}...");

      if (publicKeyRawBase64 == null) {
        throw Exception('Failed to get public key for user $peerId after retries');
      }

      RsaKeyConverter.debugPublicKey(publicKeyRawBase64);
      final remotePublicKey = RsaKeyManager.decodeRemotePublicKeyFromX509Base64(publicKeyRawBase64);
      if (remotePublicKey == null) {
        throw Exception('Invalid public key received for user $peerId');
      }

      print('Remote public key details:');
      print('  - Modulus bit length: ${remotePublicKey.modulus?.bitLength}');
      print('  - Exponent: ${remotePublicKey.exponent}');

      // Also get and verify local keys
      final localPrivateKey = await RsaKeyManager.getPrivateKey(currentUserId);
      final localPublicKey = await RsaKeyManager.getPublicKey(currentUserId);

      if (localPrivateKey != null && localPublicKey != null) {
        print('Local key pair details:');
        print('  - Private key modulus bit length: ${localPrivateKey.modulus?.bitLength}');
        print('  - Public key modulus bit length: ${localPublicKey.modulus?.bitLength}');
        print('  - Private key exponent: ${localPrivateKey.exponent}');
        print('  - Public key exponent: ${localPublicKey.exponent}');
        // Verify local key pair matches
        final keyPairMatches = RsaEncryptionManager.verifyKeyPairMatch(localPublicKey, localPrivateKey);
        print('  - Local key pair matches: $keyPairMatches');

        if (!keyPairMatches) {
          throw StateError('Local RSA key pair verification failed!');
        }
      }

      print('Received and decoded public key for user $peerId.');

      if (currentUserId < peerId) {
        print('Acting as initiator (lower ID)');
        await _initiateKeyExchangeAsInitiator(peerId, channel);
      } else {
        print('Acting as receiver (higher ID)');
        await _waitForKeyExchangeAsReceiver(peerId);
      }

      print('=== ENHANCED KEY EXCHANGE DEBUG END ===');

    } catch (e) {
      print('❌ Error during enhanced key exchange with $peerId: $e');
      print('=== ENHANCED KEY EXCHANGE DEBUG END (ERROR) ===');
      rethrow;
    }
  }
  Future<bool> _checkAesEncryptionAndDecryption(
      pc.RSAPublicKey publicKey,
      pc.RSAPrivateKey privateKey,
      String aesKeyBase66
      ) async {
    print("---Encrypting and decrypting of aes key by sender for test only---");

    try {
      final encryptedAes = RsaEncryptionManager.encryptWithPublicKey(aesKeyBase66, publicKey);
      final decryptedAes = RsaEncryptionManager.decryptWithPrivateKey(encryptedAes, privateKey);

      // Check if the decrypted key is equal to the original key
      if (decryptedAes == aesKeyBase66) {
        print("AES key encryption and decryption is successful.");
        return true;
      } else {
        print("AES key decryption result does not match the original key.");
        return false;
      }
    } catch (e) {
      print("Encryption and Decryption of AES key failed: $e");
      return false;
    }
  }
  Future<void> _initiateKeyExchangeAsInitiator(int peerId, rtc.RTCDataChannel channel) async {
    print('Initiating key exchange as initiator (ID: $currentUserId < $peerId)');


    final localPrivateKey = await RsaKeyManager.getPrivateKey(currentUserId);
    final localPublicKey = await RsaKeyManager.getPublicKey(currentUserId);





    final remoteRawBase64PublicKey =await _requestPublicKeyWithRetry(peerId);
    print("Received  Remote raw Base64 public key");

    if(remoteRawBase64PublicKey==null){
      throw Exception("Received raw public key is null");
    }



    RsaKeyConverter.debugPublicKey(remoteRawBase64PublicKey);
    final remotePublicKey = await RsaKeyConverter.decodePublicKeyFromX509Base64(remoteRawBase64PublicKey);

    if(remotePublicKey==null){
      throw Exception("Unable to decode public key");
    }

    final aesKeyBase64 = SymmetricEncryptionManager.generateAesKeyBase64();
    print('Generated new AES key for peer $peerId');

    print("remotePublicKey:${remotePublicKey}");
    final encryptedAesKey = RsaEncryptionManager.encryptWithPublicKey(aesKeyBase64, remotePublicKey);
    print("Encrypted AES key: ${encryptedAesKey}");
    print('Encrypted AES key with user $peerId\'s public key.');

   if(localPublicKey!=null && localPrivateKey!=null && aesKeyBase64!=null){
     final validEncrytionAndDecryption= _checkAesEncryptionAndDecryption(localPublicKey, localPrivateKey, aesKeyBase64);
     print("Encrytion And Decrytion:${validEncrytionAndDecryption}");
   }


    final keyExchangeMessage = SignalingMessage(
        type: 'aes_key_exchange',
        payload: encryptedAesKey,
        senderUserId: currentUserId,
        targetUserId: peerId,
        metadata: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': '1.0'
        }
    );

    await _sendDataChannelMessageWithRetry(channel, keyExchangeMessage);
    print('Sent encrypted AES key to user $peerId via DataChannel.');

    SymmetricEncryptionManager.setSharedAesKey(aesKeyBase64);
    _keyExchangeStates[peerId] = true;
    final completer = _keyExchangeCompleters[peerId];
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    listener.onKeyExchangeComplete(peerId);
    print('Key exchange completed successfully as initiator with user $peerId.');
  }




  Future<void> _waitForKeyExchangeAsReceiver(int peerId) async {
    print('Waiting for key exchange as receiver (ID: $currentUserId > $peerId)');

    // Wait for the key exchange message to arrive
    final completer = _keyExchangeCompleters[peerId];
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  Future<void> _handleAesKeyExchange(int peerId, String encryptedAesKeyBase64) async {
    if (_keyExchangeStates[peerId] == true) {
      print('Key exchange already completed for $peerId. Ignoring duplicate.');
      return;
    }

    // Declare outside so try and finally can both use them
    pc.RSAPrivateKey? localPrivateKey;
    pc.RSAPublicKey? localPublicKey;
    pc.RSAPublicKey? remotePublicKey;

    try {
      print('=== ENHANCED AES KEY EXCHANGE DEBUGGING START ===');
      print('Processing AES key exchange from $peerId...');
      print('Current user ID: $currentUserId');

      // Debug storage state before proceeding
      await RsaKeyManager.debugStorageState(currentUserId);

      // Ensure keys exist for current user
      final keysExist = await RsaKeyManager.ensureKeysExist(currentUserId);
      if (!keysExist) {
        throw StateError('Failed to ensure keys exist for current user $currentUserId');
      }

      // Enhanced Base64 validation
      if (!_isValidBase64(encryptedAesKeyBase64)) {
        throw FormatException('Invalid Base64 format in encrypted AES key');
      }
      print('✓ Encrypted AES key Base64 validation passed');

      // Decode and validate encrypted data
      Uint8List encryptedBytes;
      try {
        encryptedBytes = await base64Decode(encryptedAesKeyBase64);
        print('✓ Encrypted bytes length: ${encryptedBytes.length}');
      } catch (e) {
        throw FormatException('Failed to decode encrypted AES key from Base64: $e');
      }

      // Get local keys with enhanced error handling
      print("Retrieving public key for current user for receiver");

      final publicKeyRawBase64 = await _requestPublicKeyWithRetry(currentUserId);
      if (publicKeyRawBase64 == null) {
        throw StateError('Failed to retrieve public key for current user $currentUserId');
      }

      // Now you can safely use publicKeyRawBase64 as a non-nullable String
      RsaKeyConverter.debugPublicKey(publicKeyRawBase64);
      remotePublicKey =await RsaKeyManager.decodeRemotePublicKeyFromX509Base64(publicKeyRawBase64);
      if (remotePublicKey==null){
        print("null value is retrieved for remote public key");

      }
      localPrivateKey = await RsaKeyManager.getPrivateKey(currentUserId);

      localPublicKey = await RsaKeyManager.getPublicKey(currentUserId);
      print("Checking remotePublicKey with local public key for receiver");

      if(remotePublicKey == localPublicKey){
        print("The encryption is valid , therefore decryption shoudbe valid");
      }
      else{
        print("Remote public key user donot match with loca public key");

      }
      print("Local key retrieval results:");
      print("- Private key retrieved: ${localPrivateKey != null}");
      print("- Public key retrieved: ${localPublicKey != null}");

      if (remotePublicKey != null && localPrivateKey != null) {
        final keyPairMatches = RsaEncryptionManager.verifyKeyPairMatch(remotePublicKey, localPrivateKey);
        if (!keyPairMatches) {
          throw StateError('Local RSA key pair mismatch detected!');
        }
        print("✓ remote and local key pair validation successful");
      }
      if (localPublicKey != null && localPrivateKey != null) {
        final keyPairMatches = RsaEncryptionManager.verifyKeyPairMatch(localPublicKey, localPrivateKey);
        if (!keyPairMatches) {
          throw StateError('Local RSA key pair mismatch detected!');
        }
        print("✓  local key pair validation successful");
      }
      // Continue with decryption process...
      print('Attempting RSA decryption...');

      late final String decryptedAesKeyBase64;
      try{
      if(encryptedAesKeyBase64 != null&& localPrivateKey!= null) {
       decryptedAesKeyBase64 = RsaEncryptionManager.decryptWithPrivateKey(
            encryptedAesKeyBase64, localPrivateKey);
      }
        print("✓ AES key decryption successful.");
      } catch (e) {
        print("❌ RSA Decryption failed: $e");
        rethrow;
      }

      // Validate and set the decrypted key
      if (!_isValidBase64(decryptedAesKeyBase64)) {
        throw FormatException('Decrypted AES key is not valid Base64 format');
      }
      try {
        final keyBytes = base64Decode(decryptedAesKeyBase64);
        if (keyBytes.length != 32) {
          throw FormatException('Invalid AES key length: ${keyBytes.length} bytes (expected 32 bytes)');
        }
        print('✓ AES key length validation passed (${keyBytes.length} bytes)');
      } catch (e) {
        throw FormatException('Failed to decode AES key as Base64: $e');
      }

      // Set the AES key
      SymmetricEncryptionManager.setSharedAesKey(decryptedAesKeyBase64);
      print("✓ AES key set successfully in SymmetricEncryptionManager");

      // Mark as completed
      _keyExchangeStates[peerId] = true;
      final completer = _keyExchangeCompleters[peerId];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }

      listener.onKeyExchangeComplete(peerId);
      print('✓ Key exchange completed successfully as receiver with user $peerId.');
      print('=== ENHANCED AES KEY EXCHANGE DEBUGGING END ===');

    } catch (e) {
      print('❌ Enhanced AES key exchange error with $peerId: $e');
      final completer = _keyExchangeCompleters[peerId];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }
      listener.onError('Key exchange failed with user $peerId: $e');
      print('=== ENHANCED AES KEY EXCHANGE DEBUGGING END (ERROR) ===');
      rethrow;
    } finally {
      // These will always print no matter where the error happened
      print("local Public Key: $localPublicKey");
      print("local Private Key: $localPrivateKey");
    }
  }


// Alternative RSA decryption method using raw PointyCastle
  Future<String> _alternativeRsaDecrypt(Uint8List encryptedBytes, pc.RSAPrivateKey privateKey) async {
    try {
      print('Attempting alternative RSA decryption with PointyCastle...');

      // Create RSA engine with PKCS1 padding
      final decryptor = pc.PKCS1Encoding(pc.RSAEngine())
        ..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));

      // Decrypt the bytes
      final decryptedBytes = decryptor.process(encryptedBytes);

      // Convert to Base64 string
      final decryptedBase64 = base64Encode(decryptedBytes);

      print('✓ Alternative decryption successful');
      return decryptedBase64;

    } catch (e) {
      print('❌ Alternative decryption also failed: $e');
      rethrow;
    }
  }

  bool _isValidBase64(String input) {
    try {
      base64Decode(input);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleChatMessage(SignalingMessage message, int senderId) async {
    // Before processing, ensure that the key exchange for this specific sender
    // has been completed. This is crucial for secure communication.
    if (_keyExchangeStates[senderId] != true) {
      print('Received chat message before key exchange completed from $senderId. Ignoring.');
      listener.onError('Received chat message before key exchange from $senderId. Cannot decrypt.');
      return;
    }

    final payload = message.payload;
    if (payload == null) {
      print('Received chat message with null payload from $senderId. Ignoring.');
      listener.onError('Received chat message with null payload from $senderId.');
      return;
    }

    try {
      final decryptedMessage = SymmetricEncryptionManager.decrypt(payload);
      print('Processed chat message from $senderId: $decryptedMessage');

      final chatListener = _singlePeerChatMessageListener;
      if (chatListener != null) {
        chatListener(senderId, decryptedMessage);
      }

      listener.onChatMessageReceived(senderId, decryptedMessage);
    } catch (e) {
      print('Error decrypting or processing chat message from $senderId: $e');
      listener.onError('Failed to process chat message from $senderId: $e');
    }
  }

  Future<void> _waitForKeyExchange() async {
    if (_keyExchangeCompleted) return;

    if (_keyExchangeCompleter != null) {
      await _keyExchangeCompleter!.future;
    }
  }


  Future<String?> _requestPublicKeyWithRetry(int peerId, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Requesting public key for user $peerId (attempt $attempt/$maxRetries)');
        final publicKey = await _requestPublicKeyHttp(peerId);
        if (publicKey != null) {
          return publicKey;
        }
      } catch (e) {
        print('Attempt $attempt failed to get public key for $peerId: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        }
      }
    }
    return null;
  }

  Future<void> _sendDataChannelMessageWithRetry(rtc.RTCDataChannel channel, SignalingMessage message, {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        if (channel.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
          throw Exception('Data channel not open');
        }

        await channel.send(rtc.RTCDataChannelMessage(jsonEncode(message.toJson())));
        print('Data channel message sent successfully (attempt $attempt)');
        return;
      } catch (e) {
        print('Attempt $attempt failed to send data channel message: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        } else {
          rethrow;
        }
      }
    }
  }
  Future<void> sendChatMessage(int targetUserId, String message) async {
    if (_connectedPeerId != targetUserId) {
      throw Exception('Cannot send message: Not connected to target user $targetUserId.');
    }

    final dataChannel = _dataChannel;
    if (dataChannel == null || dataChannel.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
      print('Data channel to $targetUserId not open. Cannot send message.');
      listener.onError('Chat channel to $targetUserId is not open.');
      throw Exception('Data channel to $targetUserId not open.');
    }

    await _waitForKeyExchange();

    if (_keyExchangeStates[targetUserId] != true) { // Check single flag
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
      print('Message sent successfully to $targetUserId');

    } catch (e) {
      print('Error sending encrypted message to $targetUserId: $e');
      listener.onError('Failed to send encrypted message to $targetUserId: $e');
      rethrow;
    }
  }

  Future<void> sendFile(int targetUserId, String filePath) async {
    // Ensure targetUserId matches the currently connected peer
    if (_connectedPeerId != targetUserId) {
      listener.onError('Cannot send file: Not connected to target user $targetUserId.');
      return;
    }
    final dataChannel = _dataChannel;
    if (dataChannel == null || dataChannel.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
      listener.onError('Data channel to $targetUserId not open. Cannot send file.');
      return;
    }
    await _waitForKeyExchange();

    if (_keyExchangeStates[targetUserId] != true) { // Check single flag
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
      print('Sending file $fileName ($fileSize bytes) to $targetUserId');

      final metadata = {
        'fileId': fileId,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileType,
      };
      final encryptedMetadata = SymmetricEncryptionManager.encrypt(jsonEncode(metadata));
      final metadataMessage = SignalingMessage(
        type: 'file_metadata',
        payload: encryptedMetadata, // Send encrypted metadata here
        senderUserId: currentUserId,
        targetUserId: targetUserId,
      );
      await dataChannel.send(rtc.RTCDataChannelMessage(jsonEncode(metadataMessage.toJson())));
      print('Sent file metadata for $fileName (ID: $fileId) to $targetUserId.');

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
        for (int j = 0; j < 16; j++) {
          if (j < fileIdBytes.length) {
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

        await dataChannel.send(rtc.RTCDataChannelMessage.fromBinary(chunkWithHeader));
        listener.onFileChunkReceived(fileId, i + 1, totalChunks);
      }
      print('File $fileName (ID: $fileId) sent completely to $targetUserId.');
      listener.onFileTransferComplete(fileId, fileName, currentUserId, filePath);
    } catch (e) {
      print('Error sending file $filePath to $targetUserId: $e');
      listener.onError('Failed to send file: $e');
    }
  }

  String _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  void disposeAll() {
    if (_connectedPeerId != null) {
      disposePeerConnection(_connectedPeerId!); // Dispose the single connected peer
    }
    _connectedPeerId = null;
    _keyExchangeCompleted = false;
    _incomingFileBuffers.clear();
    _incomingFileNames.clear();
    _incomingFileSizes.clear();
    _singlePeerChatMessageListener = null; // Clear single listener
  }

  /// Disposes the peer connection with a specific ID (should be the active one).
  Future<void> disposePeerConnection(int peerId) async { // Changed parameter to non-nullable int
    print('Disposing peer connection for $peerId');

    if (_connectedPeerId != peerId){
      print('Not disposing - peer $peerId is not the current connected peer');
      return;
    }

    try {
      final dataChannel = _dataChannel;
      if (dataChannel != null) {
        await dataChannel.close();
        _dataChannel = null;
        print('Data channel closed for peer $peerId');
      }

      final peerConnection = _peerConnection;
      if (peerConnection != null) {
        await peerConnection.close();
        _peerConnection = null;
        print('Peer connection closed for peer $peerId');
      }

      // Reset connection state
      _isConnected = false;
      _isDataChannelOpen = false;
      _connectedPeerId = null;
      _reconnectAttempts = 0;
      _keyExchangeCompleted = false;
      _keyExchangeInProgress = false;
      _keyExchangeCompleter?.complete();
      _keyExchangeCompleter = null;

      _keyExchangeStates.remove(peerId);
      _keyExchangeInProgressStates.remove(peerId);
      _keyExchangeCompleters.remove(peerId);
      _incomingFileBuffers.clear();
      _incomingFileNames.clear();
      _incomingFileSizes.clear();
      _singlePeerChatMessageListener = null;



      print('Peer connection disposed successfully for peer $peerId');
      listener.onPeerDisconnected(peerId);
    } catch (e) {
      print('Error disposing peer connection for $peerId: $e');
      listener.onError('Error disposing connection for peer $peerId: $e');
    }
  }
  void _cleanup() {
    print('Performing WebRTC client cleanup...');

    try {

      final dataChannel = _dataChannel;
      if (dataChannel != null) {
        dataChannel.close();
        _dataChannel = null;
      }

      final peerConnection = _peerConnection;
      if (peerConnection != null) {
        peerConnection.close();
        _peerConnection = null;
      }
      _keyExchangeStates.clear();
      _keyExchangeInProgressStates.clear();
      _keyExchangeCompleters.forEach((peerId, completer) {
        if (!completer.isCompleted) {
          completer.completeError('Connection cleanup');
        }
      });
      _keyExchangeCompleters.clear();
      _isConnected = false;
      _isDataChannelOpen = false;
      _connectedPeerId = null;
      _reconnectAttempts = 0;

      // Clean up key exchange state
      _keyExchangeCompleted = false;
      _keyExchangeInProgress = false;
      _keyExchangeCompleter?.complete();
      _keyExchangeCompleter = null;

      // Clean up file transfer buffers
      _incomingFileBuffers.clear();
      _incomingFileNames.clear();
      _incomingFileSizes.clear();

      // Remove listeners
      _singlePeerChatMessageListener = null;



      print('WebRTC client cleanup completed');
    } catch (e) {
      print('Error during WebRTC client cleanup: $e');
      listener.onError('Error during cleanup: $e');
    }
  }

  Future<void> dispose() async {
    print('Disposing WebRTC client...');

    try {
      if (_connectedPeerId != null) {
        await disposePeerConnection(_connectedPeerId!);
      }

      _cleanup();

      if (_isSignalingConnected) {
        await signalingClient.disconnect();
        _isSignalingConnected = false;
      }

      print('WebRTC client disposed successfully');
    } catch (e) {
      print('Error disposing WebRTC client: $e');
      listener.onError('Error disposing WebRTC client: $e');
    }
  }



  @override
  void onMessage(SignalingMessage message) async {
    _lastSignalingMessage = DateTime.now();
    print('WebRtcClient received signaling message: ${message.type} from ${message.senderUserId}');

    final peerId = message.senderUserId;

    if (peerId == null || peerId == currentUserId) {
      print('Received signaling message without valid sender ID or from self. Ignoring');
      return; // Add this return statement
    }

    if (!_validateSignalingMessage(message)) {
      print('Invalid signaling message structure. Ignoring.');
      return;
    }

    try {
      if (_peerConnection == null) {
        if (_connectedPeerId == null) {
          _connectedPeerId = peerId;
          _peerConnection = await _createAndConfigurePeerConnection(peerId);
        } else if (_connectedPeerId != peerId) {
          print('Warning: Received signaling message from unexpected peer $peerId. Expected $_connectedPeerId. Ignoring.');
          return;
        }
      }

      await _processSignalingMessage(message, peerId); // Now peerId is guaranteed to be non-null

    } catch (e) {
      print('Error processing signaling message from $peerId: $e');
      listener.onError('Failed to process signaling message from $peerId: $e');
    }
  }


  bool _validateSignalingMessage(SignalingMessage message) {

    switch (message.type) {
      case 'offer':
      case 'answer':
        return message.payload != null && message.payload!.isNotEmpty;
      case 'candidate':
        if(message.payload==null){
          return false;
        }
        try {
          final payload = message.payload!;
          final candidateMap = jsonDecode(payload);
          return candidateMap['candidate'] != null;
        } catch (e) {
          return false;
        }
      case 'aes_key_exchange':
        return message.payload != null && message.payload!.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _processSignalingMessage(SignalingMessage message, int peerId) async {
    print('WebRtcClient received signaling message type: ${message.type} from $peerId');

    // Ensure _connectedPeerId is set if a message is received from a new peer
    if (_connectedPeerId == null) {
      print('Auto-setting _connectedPeerId to $peerId from incoming signaling message.');
      _connectedPeerId = peerId;
      _resetConnectionState();
    } else if (_connectedPeerId != peerId) {
      print('Warning: Received message from $peerId but connected to $_connectedPeerId. Ignoring message unless it\'s an offer or specific control message.');
      return;
    }
    switch (message.type) {
      case 'offer':
        await _handleOffer(message, peerId);
        break;
      case 'answer':
        await _handleAnswer(message, peerId);
        break;
      case 'candidate':
        await _handleCandidate(message, peerId);
        break;
      case 'aes_key_exchange':
      // Removed `message.metadata` argument
        await _handleAesKeyExchange(peerId, message.payload!);
        break;
      case 'chat-message':
        await _handleChatMessage(message,peerId);
      default:
        print('Unhandled signaling message type: ${message.type}');
        break;
    }
  }

  // Fixed _handleOffer method - send SDP string directly
  Future<void> _handleOffer(SignalingMessage message, int peerId) async {
    if (message.payload == null || message.senderUserId == null) {
      print('Received invalid offer: payload or senderUserId is null.');
      listener.onError('Received invalid offer message.');
      return;
    }
    final senderUserId = message.senderUserId!;
    print('Handling offer from $senderUserId');

    _connectedPeerId = senderUserId; // Ensure connectedPeerId is set for the incoming offer

    // Ensure _peerConnection is created and not null
    try {
      _peerConnection = await _createAndConfigurePeerConnection(senderUserId);

      if (_peerConnection == null) {
        print('Error: _createPeerConnection failed to initialize _peerConnection.');
        listener.onError('Failed to create WebRTC peer connection for offer.');
        return; // Critical failure, stop processing
      }
    } catch (e) {
      print('Exception during _createPeerConnection in _handleOffer: $e');
      listener.onError('Error establishing WebRTC connection: $e');
      return; // Critical failure, stop processing
    }

    await _peerConnection!.setRemoteDescription(
      rtc.RTCSessionDescription(message.payload, 'offer'),
    );

    final rtc.RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    print('Sending answer to $senderUserId: ${answer.sdp}');
    signalingClient.send(SignalingMessage(
      type: 'answer',
      payload: answer.sdp, // Send SDP string directly, not JSON encoded
      senderUserId: currentUserId,
      targetUserId: senderUserId,
    ));
    listener.onNewPeerConnected(senderUserId, 'User $senderUserId');
  }


  Future<void> _handleAnswer(SignalingMessage message, int peerId) async {
    if (message.payload == null || message.senderUserId == null) {
      print('Received invalid answer: payload or senderUserId is null.');
      listener.onError('Received invalid answer message.');
      return;
    }
    final payload = message.payload!;
    final senderUserId = message.senderUserId!;
    print('Handling answer from $senderUserId');

    if (_peerConnection == null) {
      print('Error: _peerConnection is null when handling answer from $senderUserId. Cannot set remote description.');
      listener.onError('WebRTC connection not established for answer.');
      return; // Abort if peer connection is not ready
    }

    await _peerConnection!.setRemoteDescription(
      rtc.RTCSessionDescription(payload, 'answer'),
    );
  }
  Future<void> _handleCandidate(SignalingMessage message, int peerId) async {
    if (message.payload == null || message.senderUserId == null) {
      print('Received invalid ICE candidate: payload or senderUserId is null.');
      listener.onError('Received invalid ICE candidate message.');
      return;
    }
    final payload = message.payload!;
    final senderUserId = message.senderUserId!;
    print('Handling ICE candidate from $senderUserId');

    // Check if _peerConnection is null before using it
    if (_peerConnection == null) {
      print('Error: _peerConnection is null when handling ICE candidate from $senderUserId. Cannot add candidate.');
      listener.onError('WebRTC connection not established for ICE candidate.');
      return; // Abort if peer connection is not ready
    }

    try {
      final Map<String, dynamic> candidateMap = jsonDecode(payload);
      final rtc.RTCIceCandidate candidate = rtc.RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error adding ICE candidate from $senderUserId: $e');
      listener.onError('Failed to handle ICE candidate: $e');
    }
  }


  void _handleReconnection(int peerId) {
    if (_reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
      _reconnectAttempts++;
      print('Attempting reconnection $peerId (attempt $_reconnectAttempts/$MAX_RECONNECT_ATTEMPTS)');

      // Reset key exchange state for reconnection
      _keyExchangeStates[peerId] = false;
      _keyExchangeInProgressStates[peerId] = false;

      Future.delayed(Duration(seconds: _reconnectAttempts * 2), () {
        if (_connectedPeerId == peerId) {
          initiateCall(peerId);
        }
      });
    } else {
      print('Max reconnection attempts reached for peer $peerId');
      listener.onError('Failed to reconnect to peer $peerId after $_reconnectAttempts attempts');
      disposePeerConnection(peerId);
    }
  }

  void _handleConnectionFailure(int peerId) {
    print('Handling connection failure for peer $peerId');
    _keyExchangeStates[peerId] = false;
    _keyExchangeInProgressStates[peerId] = false;
    _keyExchangeCompleters[peerId]?.completeError('Connection failed');
    listener.onError('Connection failed with peer $peerId');
    listener.onPeerDisconnected(peerId);
  }


  bool isConnectedTo(int peerId) {
    return _connectedPeerId == peerId && _isConnected && _isDataChannelOpen;
  }

  Map<String, dynamic> getConnectionDiagnostics() {
    return {
      'connectedPeerId': _connectedPeerId,
      'isConnected': _isConnected,
      'isDataChannelOpen': _isDataChannelOpen,
      'keyExchangeCompleted': _keyExchangeCompleted,
      'peerConnectionState': _peerConnection?.connectionState?.toString(),
      'dataChannelState': _dataChannel?.state?.toString(),
      'reconnectAttempts': _reconnectAttempts,
    };
  }

  bool isSignalingHealthy() {
    if (!_isSignalingConnected) return false;

    if (_lastSignalingMessage == null) return false;

    return DateTime.now().difference(_lastSignalingMessage!) < Duration(seconds: 30);
  }

  // Add comprehensive status check
  Map<String, dynamic> getFullStatus() {
    return {
      'signaling': {
        'connected': _isSignalingConnected,
        'lastMessage': _lastSignalingMessage?.toIso8601String(),
        'healthy': isSignalingHealthy(),
      },
      'webrtc': getConnectionDiagnostics(),
    };
  }

  @override
  void onOpen() {
    _isSignalingConnected = true;
    print('Signaling connection opened. Ready for WebRTC.');
  }

  @override
  void onClose(int? code, String? reason) {
    _isSignalingConnected = false;
    print('Signaling connection closed. Code: $code, Reason: $reason');
    // Ensure that _connectedPeerId is non-null before passing it
    if (_connectedPeerId != null) {
      disposePeerConnection(_connectedPeerId!);
    }
  }

  @override
  void onError(dynamic error) {
    print('Signaling connection error: $error');
    listener.onError('Signaling error: $error');
    // Ensure that _connectedPeerId is non-null before passing it
    if (_connectedPeerId != null) {
      disposePeerConnection(_connectedPeerId!);
    }
  }

  Future<String?> _requestPublicKeyHttp(int targetUserId) async {
    try {
      final response = await _dio.get(
        '/public-key',
        data: {
          'targetUserId': targetUserId,
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = response.data as Map<String, dynamic>;

        if (jsonResponse['success'] == true) { // Check backend's success flag
          final String? publicKeyPem = jsonResponse['publicKeyPem'] as String?; // Assuming backend sends 'publicKeyPem'
          if (publicKeyPem != null) {
            print('Successfully fetched public key for user $targetUserId.');
            return publicKeyPem;
          } else {
            print('Error: publicKeyPem field missing in response for $targetUserId: ${response.data}');
            listener.onError('Public key not found in response for user $targetUserId.');
            return null;
          }
        } else {
          print('Failed to fetch public key: ${jsonResponse['message']}');
          listener.onError('Failed to fetch public key: ${jsonResponse['message']}');
          return null;
        }
      } else {
        print('Failed to fetch public key via HTTP for $targetUserId: Status ${response.statusCode} - ${response.data}');
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