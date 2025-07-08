package com.example.videocall

import android.util.Log
import io.socket.client.IO
import io.socket.client.Socket
import org.json.JSONObject

class SignalingClient {

    private lateinit var socket: Socket
    private val serverUrl = "http://your-server-ip:3000"  // Replace with your signaling server

    init {
        try {
            socket = IO.socket(serverUrl)

            socket.on(Socket.EVENT_CONNECT) {
                Log.d("SignalingClient", "Connected to signaling server")
            }

            socket.on("offer") { args ->
                val data = args[0] as JSONObject
                onOfferReceived?.invoke(data)
            }

            socket.on("answer") { args ->
                val data = args[0] as JSONObject
                onAnswerReceived?.invoke(data)
            }

            socket.on("ice-candidate") { args ->
                val data = args[0] as JSONObject
                onIceCandidateReceived?.invoke(data)
            }

            socket.connect()

        } catch (e: Exception) {
            Log.e("SignalingClient", "Error initializing socket: ${e.message}")
        }
    }

    // Callbacks
    var onOfferReceived: ((JSONObject) -> Unit)? = null
    var onAnswerReceived: ((JSONObject) -> Unit)? = null
    var onIceCandidateReceived: ((JSONObject) -> Unit)? = null

    fun sendCallRequest(toUser: String) {
        val data = JSONObject()
        data.put("to", toUser)
        socket.emit("call", data)
    }

    fun sendOffer(offer: JSONObject) {
        socket.emit("offer", offer)
    }

    fun sendAnswer(answer: JSONObject) {
        socket.emit("answer", answer)
    }

    fun sendIceCandidate(candidate: JSONObject) {
        socket.emit("ice-candidate", candidate)
    }

    fun disconnect() {
        socket.disconnect()
    }
}
