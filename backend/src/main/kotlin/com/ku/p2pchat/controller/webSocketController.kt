package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import org.eclipse.jetty.websocket.api.Session
import jakarta.servlet.annotation.WebServlet
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect
import org.eclipse.jetty.websocket.api.annotations.WebSocket
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketClose
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketError
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage
import org.eclipse.jetty.websocket.server.JettyWebSocketServlet
import org.eclipse.jetty.websocket.server.JettyWebSocketServletFactory
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import java.util.concurrent.ConcurrentHashMap
import jakarta.servlet.http.HttpServletResponse

// WebSocket message data classes
data class WebSocketMessage(
    val type: String,
    val data: Any? = null,
    val message: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

data class OnlineUserData(
    val id: Int,
    val firstname: String,
    val lastname: String,
    val email: String,
    val fullName: String = "$firstname $lastname"
)

@WebServlet("/websocket")
class WebSocketServlet : JettyWebSocketServlet() {
    private lateinit var userDao: userLogindaoImp

    override fun init() {
        super.init()
        userDao = userLogindaoImp()
    }

    override fun configure(factory: JettyWebSocketServletFactory) {
        factory.setIdleTimeout(java.time.Duration.ofMinutes(10))

        factory.setCreator { req, resp ->
            // Get userId from request headers (as sent by Flutter client)
            val userIdHeader = req.getHeader("userId")
            val userId = userIdHeader?.toIntOrNull()

            if (userId == null) {
                resp.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Missing or invalid userId header")
                println("WebSocket connection rejected: Missing or invalid userId header")
                null
            } else {
                // Fetch user data from database
                val user = userDao.findUserById(userId)

                if (user != null) {
                    println("WebSocket connection authorized for user: ${user.firstName} ${user.lastName} (ID: ${user.id})")
                    ChatWebSocket(user, userDao)
                } else {
                    resp.sendError(HttpServletResponse.SC_NOT_FOUND, "User not found")
                    println("WebSocket connection rejected: User not found for ID: $userId")
                    null
                }
            }
        }
    }
}

@WebSocket
class ChatWebSocket(private val user: user, private val userDao: userLogindaoImp) {
    private lateinit var session: Session
    private val gson = Gson()

    companion object {
        // Store active WebSocket sessions
        private val activeSessions = ConcurrentHashMap<Int, Session>()
        private val activeUsers = ConcurrentHashMap<Int, user>()

        // Broadcast message to all connected users
        fun broadcastToAll(message: WebSocketMessage, excludeUserId: Int? = null) {
            val gson = Gson()
            val messageJson = gson.toJson(message)

            activeSessions.forEach { (userId, session) ->
                if (excludeUserId == null || userId != excludeUserId) {
                    try {
                        if (session.isOpen) {
                            session.remote.sendString(messageJson)
                        } else {
                            // Clean up closed sessions
                            activeSessions.remove(userId)
                            activeUsers.remove(userId)
                        }
                    } catch (e: Exception) {
                        println("Error broadcasting to user $userId: ${e.message}")
                        // Clean up failed sessions
                        activeSessions.remove(userId)
                        activeUsers.remove(userId)
                    }
                }
            }
        }

        // Get all currently online users
        fun getOnlineUsers(): List<OnlineUserData> {
            return activeUsers.values.map { user ->
                OnlineUserData(
                    id = user.id,
                    firstname = user.firstName,
                    lastname = user.lastName,
                    email = user.email
                )
            }
        }
    }

    @OnWebSocketConnect
    fun onConnect(session: Session) {
        this.session = session

        // Add to active sessions
        activeSessions[user.id] = session
        activeUsers[user.id] = user

        println("User ${user.firstName} ${user.lastName} (ID: ${user.id}) connected to WebSocket")

        // Send current online users list to the newly connected user
        val onlineUsers = getOnlineUsers()
        val onlineUsersMessage = WebSocketMessage(
            type = "online_users_update",
            data = onlineUsers,
            message = "Current online users"
        )

        try {
            session.remote.sendString(gson.toJson(onlineUsersMessage))
            println("Sent online users list to user ${user.id}: ${onlineUsers.size} users")
        } catch (e: Exception) {
            println("Error sending online users list to user ${user.id}: ${e.message}")
        }

        // Broadcast to other users that this user came online
        val userOnlineMessage = WebSocketMessage(
            type = "user_online",
            data = OnlineUserData(
                id = user.id,
                firstname = user.firstName,
                lastname = user.lastName,
                email = user.email
            ),
            message = "${user.firstName} ${user.lastName} is now online"
        )

        broadcastToAll(userOnlineMessage, excludeUserId = user.id)

        // Send updated online users list to all users
        broadcastOnlineUsersUpdate()
    }

    @OnWebSocketMessage
    fun onMessage(message: String?) {
        if (message == null) return

        println("Received message from user ${user.id}: $message")

        try {
            val receivedMessage = gson.fromJson(message, WebSocketMessage::class.java)

            when (receivedMessage.type) {
                "ping" -> {
                    // Respond to ping with pong
                    val pongMessage = WebSocketMessage(
                        type = "pong",
                        message = "Server is alive"
                    )
                    session.remote.sendString(gson.toJson(pongMessage))
                }

                "request_online_users" -> {
                    // Send current online users list
                    val onlineUsers = getOnlineUsers()
                    val onlineUsersMessage = WebSocketMessage(
                        type = "online_users_update",
                        data = onlineUsers,
                        message = "Requested online users list"
                    )
                    session.remote.sendString(gson.toJson(onlineUsersMessage))
                }

                "chat_message" -> {
                    // Handle chat messages (relay to specific user or broadcast)
                    // This is a placeholder - implement according to your chat logic
                    println("Chat message received from user ${user.id}: ${receivedMessage.message}")
                }

                else -> {
                    println("Unknown message type received from user ${user.id}: ${receivedMessage.type}")
                    val errorMessage = WebSocketMessage(
                        type = "error",
                        message = "Unknown message type: ${receivedMessage.type}"
                    )
                    session.remote.sendString(gson.toJson(errorMessage))
                }
            }
        } catch (e: Exception) {
            println("Error processing message from user ${user.id}: ${e.message}")
            val errorMessage = WebSocketMessage(
                type = "error",
                message = "Error processing message: ${e.message}"
            )
            try {
                session.remote.sendString(gson.toJson(errorMessage))
            } catch (sendError: Exception) {
                println("Error sending error message to user ${user.id}: ${sendError.message}")
            }
        }
    }

    @OnWebSocketClose
    fun onClose(statusCode: Int, reason: String?) {
        println("User ${user.id} WebSocket disconnected. Status: $statusCode, Reason: $reason")

        // Remove from active sessions
        activeSessions.remove(user.id)
        activeUsers.remove(user.id)

        // Broadcast to other users that this user went offline
        val userOfflineMessage = WebSocketMessage(
            type = "user_offline",
            data = OnlineUserData(
                id = user.id,
                firstname = user.firstName,
                lastname = user.lastName,
                email = user.email
            ),
            message = "${user.firstName} ${user.lastName} went offline"
        )

        broadcastToAll(userOfflineMessage)

        // Send updated online users list to all remaining users
        broadcastOnlineUsersUpdate()
    }

    @OnWebSocketError
    fun onError(cause: Throwable?) {
        println("WebSocket error for user ${user.id}: ${cause?.message}")
        cause?.printStackTrace()

        // Remove from active sessions
        activeSessions.remove(user.id)
        activeUsers.remove(user.id)

        // Broadcast to other users that this user went offline due to error
        val userOfflineMessage = WebSocketMessage(
            type = "user_offline",
            data = OnlineUserData(
                id = user.id,
                firstname = user.firstName,
                lastname = user.lastName,
                email = user.email
            ),
            message = "${user.firstName} ${user.lastName} went offline due to an error"
        )

        broadcastToAll(userOfflineMessage)

        // Send updated online users list to all remaining users
        broadcastOnlineUsersUpdate()
    }

    private fun broadcastOnlineUsersUpdate() {
        val onlineUsers = getOnlineUsers()
        val onlineUsersMessage = WebSocketMessage(
            type = "online_users_update",
            data = onlineUsers,
            message = "Updated online users list"
        )

        broadcastToAll(onlineUsersMessage)
    }
}

// Session controller for managing WebSocket sessions (if you want to integrate with your existing sessionController)
object WebSocketSessionController {
    fun getOnlineUsersCount(): Int {
        return ChatWebSocket.getOnlineUsers().size
    }

    fun getOnlineUsers(): List<OnlineUserData> {
        return ChatWebSocket.getOnlineUsers()
    }

    fun broadcastMessage(message: WebSocketMessage, excludeUserId: Int? = null) {
        ChatWebSocket.broadcastToAll(message, excludeUserId)
    }
}