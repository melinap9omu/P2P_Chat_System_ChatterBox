package org.example.com.ku.p2pchat.websocket

import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.channels.ClosedReceiveChannelException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.SignalingMessage
import java.util.concurrent.ConcurrentHashMap

class SignalingServer {
    private val connections = ConcurrentHashMap<Int, DefaultWebSocketServerSession>()
    
    suspend fun handleConnection(session: DefaultWebSocketServerSession, userId: Int) {
        connections[userId] = session
        println("User $userId connected. Total connections: ${connections.size}")
        
        try {
            for (frame in session.incoming) {
                when (frame) {
                    is Frame.Text -> {
                        try {
                            val message = Json.decodeFromString<SignalingMessage>(frame.readText())
                            handleSignalingMessage(message, userId)
                        } catch (e: Exception) {
                            println("Error parsing message: ${e.message}")
                        }
                    }
                    else -> {}
                }
            }
        } catch (e: ClosedReceiveChannelException) {
            println("Connection closed for user $userId")
        } finally {
            connections.remove(userId)
            println("User $userId disconnected. Total connections: ${connections.size}")
        }
    }
    
    private suspend fun handleSignalingMessage(message: SignalingMessage, senderId: Int) {
        message.targetUserId?.let { targetId ->
            val targetConnection = connections[targetId]
            if (targetConnection != null) {
                val messageWithSender = message.copy(senderUserId = senderId)
                val jsonMessage = Json.encodeToString(messageWithSender)
                targetConnection.send(Frame.Text(jsonMessage))
                println("Message sent from $senderId to $targetId: ${message.type}")
            } else {
                println("Target user $targetId not connected")
            }
        }
    }
}