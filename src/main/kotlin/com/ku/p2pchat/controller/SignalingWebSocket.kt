package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import org.eclipse.jetty.websocket.api.Session
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketClose
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketError
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage
import org.eclipse.jetty.websocket.api.annotations.WebSocket
import java.util.concurrent.ConcurrentHashMap

@WebSocket
class SignalingWebSocket {
    companion object {
        val sessions = ConcurrentHashMap<Session, String>()
    }

    @OnWebSocketConnect
    fun onConnect(session: Session) {
        println("🟢 Connected: ${session.remoteAddress}")
        sessions[session] = "connected"
    }

    @OnWebSocketMessage
    fun onMessage(session: Session, message: String) {
        println("📩 Message: $message from ${session.remoteAddress}")
        // Broadcast to others
        sessions.keys.filter { it != session && it.isOpen }.forEach {
            it.remote.sendString(message)
        }
    }

    @OnWebSocketClose
    fun onClose(session: Session, statusCode: Int, reason: String?) {
        println("🔴 Disconnected: ${session.remoteAddress} -> $reason")
        sessions.remove(session)
    }

    @OnWebSocketError
    fun onError(session: Session?, error: Throwable) {
        println("❌ Error: ${error.message}")
    }
}