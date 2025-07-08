class VideoCallActivity : AppCompatActivity() {
    private lateinit var peerConnectionFactory: PeerConnectionFactory
    private lateinit var localVideoTrack: VideoTrack
    private lateinit var localAudioTrack: AudioTrack
    private lateinit var localSurfaceView: SurfaceViewRenderer
    private lateinit var remoteSurfaceView: SurfaceViewRenderer
    private lateinit var socket: Socket
    private var peerConnection: PeerConnection? = null

    private val ICE_SERVERS = listOf(
        PeerConnection.IceServer.builder("stun:stun.l.google.com:19302").createIceServer()
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_video_call)

        localSurfaceView = findViewById(R.id.local_view)
        remoteSurfaceView = findViewById(R.id.remote_view)

        initWebRTC()
        initSocket()
    }

    private fun initWebRTC() {
        PeerConnectionFactory.initialize(
            PeerConnectionFactory.InitializationOptions.builder(this)
                .createInitializationOptions()
        )

        val options = PeerConnectionFactory.Options()
        val encoderFactory = DefaultVideoEncoderFactory(
            EglBase.create().eglBaseContext, true, true
        )
        val decoderFactory = DefaultVideoDecoderFactory(EglBase.create().eglBaseContext)

        peerConnectionFactory = PeerConnectionFactory.builder()
            .setOptions(options)
            .setVideoEncoderFactory(encoderFactory)
            .setVideoDecoderFactory(decoderFactory)
            .createPeerConnectionFactory()

        val videoCapturer = createCameraCapturer()
        val surfaceTextureHelper = SurfaceTextureHelper.create("CaptureThread", EglBase.create().eglBaseContext)

        val videoSource = peerConnectionFactory.createVideoSource(videoCapturer!!.isScreencast)
        videoCapturer.initialize(surfaceTextureHelper, applicationContext, videoSource.capturerObserver)
        videoCapturer.startCapture(720, 1280, 30)

        localVideoTrack = peerConnectionFactory.createVideoTrack("videoTrack", videoSource)
        localAudioTrack = peerConnectionFactory.createAudioTrack("audioTrack", peerConnectionFactory.createAudioSource(MediaConstraints()))

        localSurfaceView.init(EglBase.create().eglBaseContext, null)
        localSurfaceView.setMirror(true)
        localVideoTrack.addSink(localSurfaceView)

        startPeerConnection()
    }

    private fun startPeerConnection() {
        val rtcConfig = PeerConnection.RTCConfiguration(ICE_SERVERS)
        peerConnection = peerConnectionFactory.createPeerConnection(rtcConfig, object : PeerConnection.Observer {
            override fun onIceCandidate(candidate: IceCandidate?) {
                // Send candidate to peer via socket
                candidate?.let {
                    val json = JSONObject()
                    json.put("type", "candidate")
                    json.put("sdpMLineIndex", it.sdpMLineIndex)
                    json.put("sdpMid", it.sdpMid)
                    json.put("candidate", it.sdp)
                    socket.emit("candidate", json)
                }
            }

            override fun onAddStream(stream: MediaStream?) {
                runOnUiThread {
                    stream?.videoTracks?.get(0)?.addSink(remoteSurfaceView)
                }
            }

            // Handle other events...
            override fun onSignalingChange(newState: PeerConnection.SignalingState?) {}
            override fun onIceConnectionChange(newState: PeerConnection.IceConnectionState?) {}
            override fun onIceGatheringChange(newState: PeerConnection.IceGatheringState?) {}
            override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>?) {}
            override fun onAddTrack(receiver: RtpReceiver?, streams: Array<out MediaStream>?) {}
            override fun onDataChannel(dc: DataChannel?) {}
            override fun onConnectionChange(newState: PeerConnection.PeerConnectionState?) {}
            override fun onTrack(transceiver: RtpTransceiver?) {}
            override fun onRenegotiationNeeded() {}
        })

        val stream = peerConnectionFactory.createLocalMediaStream("stream")
        stream.addTrack(localVideoTrack)
        stream.addTrack(localAudioTrack)
        peerConnection?.addStream(stream)
    }

    private fun initSocket() {
        socket = IO.socket("http://your-server.com:3000") // Replace with your signaling server
        socket.connect()

        socket.on("offer") { args ->
            val data = args[0] as JSONObject
            val sdp = SessionDescription(SessionDescription.Type.OFFER, data.getString("sdp"))
            peerConnection?.setRemoteDescription(object : SdpObserverAdapter() {}, sdp)

            // Answer
            peerConnection?.createAnswer(object : SdpObserverAdapter() {
                override fun onCreateSuccess(desc: SessionDescription?) {
                    peerConnection?.setLocalDescription(object : SdpObserverAdapter() {}, desc)
                    val answer = JSONObject()
                    answer.put("type", "answer")
                    answer.put("sdp", desc?.description)
                    socket.emit("answer", answer)
                }
            }, MediaConstraints())
        }

        socket.on("answer") { args ->
            val data = args[0] as JSONObject
            val sdp = SessionDescription(SessionDescription.Type.ANSWER, data.getString("sdp"))
            peerConnection?.setRemoteDescription(object : SdpObserverAdapter() {}, sdp)
        }

        socket.on("candidate") { args ->
            val data = args[0] as JSONObject
            val candidate = IceCandidate(
                data.getString("sdpMid"),
                data.getInt("sdpMLineIndex"),
                data.getString("candidate")
            )
            peerConnection?.addIceCandidate(candidate)
        }
    }

    private fun createCameraCapturer(): CameraVideoCapturer? {
        val enumerator = Camera2Enumerator(this)
        val deviceNames = enumerator.deviceNames

        for (deviceName in deviceNames) {
            if (enumerator.isFrontFacing(deviceName)) {
                return enumerator.createCapturer(deviceName, null)
            }
        }
        return null
    }
}
