package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import java.time.Duration
import org.eclipse.jetty.websocket.api.Session
import jakarta.servlet.annotation.WebServlet
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect
import org.eclipse.jetty.websocket.api.annotations.WebSocket
import jakarta.servlet.http.HttpSession
import jakarta.servlet.http.HttpServletResponse
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketClose
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketError
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage
import org.eclipse.jetty.websocket.server.JettyWebSocketServlet
import org.eclipse.jetty.websocket.server.JettyWebSocketServletFactory
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.SignalingMessage


@WebServlet("/signal")
class signalControllee : JettyWebSocketServlet(){
    private lateinit var userDao: userLogindaoImp
    override fun init(){
        super.init()
        userDao= userLogindaoImp()
    }

    override fun configure(factory: JettyWebSocketServletFactory){
        factory.idleTimeout = Duration.ofMillis(60000) // Set idle timeout to 60 seconds (60000 milliseconds)
        factory.setCreator { req, resp->
            val httpSession = req.session as? HttpSession
            val userId = httpSession?.getAttribute("userId") as? Int

            if (userId==null){
                resp.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Unauthorized WebSocket Connection")
                println("WebSocket connection rejected: User not authorized")
                null
            }
            else{
                val User = sessionController.getUserById(userId)
                val authenticatedUser = User ?:userDao.findUserById(userId)

                if (authenticatedUser!=null){
                    println("WebSocket connection authorized for user: ${authenticatedUser}")
                    SignalingSocket(authenticatedUser)
                }
                else{
                    resp.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "User data was not found for authenticated session")
                    println("WebSocket connection rejected: User data missing for authenticated session ID: ${userId}")
                    null
                }
            }
        }
    }
}

@WebSocket
class SignalingSocket(private val user: user) {
    private lateinit var session: Session
    private val gson = Gson()

    @OnWebSocketConnect
    fun onConnect(session: Session) {
        this.session = session
        sessionController.addSession(user, session)
        println("User ${user.firstName} (${user.id}) WebSocket connected.")

        // Send initial online users list with consistent structure
        val onlineUsers = sessionController.getAllOnlineUsers().map { onlineUser ->
            mapOf(
                "id" to onlineUser.id,
                "firstName" to onlineUser.firstName,
                "lastName" to onlineUser.lastName,
                "email" to onlineUser.email,
                "phoneNo" to onlineUser.phoneNo,
                "publicKeyPem" to onlineUser.publicKeyPem,
                "fullName" to "${onlineUser.firstName} ${onlineUser.lastName}"
            )
        }.toList()

        val initialListMessage = mapOf(
            "type" to "online_users_update",
            "data" to onlineUsers,
            "message" to "Current online users list"
        )

        try {
            session.remote.sendString(gson.toJson(initialListMessage))
            println("Sent initial online users list to user ${user.id}.")
        } catch (e: Exception) {
            System.err.println("Error sending initial online users list to user ${user.id}: ${e.message}")
            e.printStackTrace()
        }

        // Broadcast user online to others with consistent structure
        val userOnlineMessage = mapOf(
            "type" to "user_online",
            "data" to mapOf(
                "id" to user.id,
                "firstName" to user.firstName,
                "lastName" to user.lastName,
                "email" to user.email,
                "phoneNo" to user.phoneNo,
                "publicKeyPem" to user.publicKeyPem,
                "fullName" to "${user.firstName} ${user.lastName}"
            ),
            "message" to "${user.firstName} ${user.lastName} is now online."
        )

        sessionController.broadcastMessage(
            SignalingMessage(
                type = "user_online",
                senderUserId = user.id,
                senderUsername = "${user.firstName} ${user.lastName}",
                message = gson.toJson(userOnlineMessage)
            ),
            excludeUserId = user.id
        )
    }

    @OnWebSocketMessage
    fun onMessage(message: String?) {
        if (message == null) return
        println("Received message from User ${user.id}: $message")

        try {
            val messageMap = gson.fromJson(message, Map::class.java) as Map<String, Any>
            val messageType = messageMap["type"] as? String

            when (messageType) {
                "ping" -> {
                    // Respond to ping with pong
                    val pongMessage = mapOf("type" to "pong")
                    session.remote.sendString(gson.toJson(pongMessage))
                    println("Sent pong to user ${user.id}")
                }
                "request_online_users" -> {
                    // Send current online users list
                    val onlineUsers = sessionController.getAllOnlineUsers().map { onlineUser ->
                        mapOf(
                            "id" to onlineUser.id,
                            "firstName" to onlineUser.firstName,
                            "lastName" to onlineUser.lastName,
                            "email" to onlineUser.email,
                            "phoneNo" to onlineUser.phoneNo,
                            "publicKeyPem" to onlineUser.publicKeyPem,
                            "fullName" to "${onlineUser.firstName} ${onlineUser.lastName}"
                        )
                    }.toList()

                    val onlineUsersMessage = mapOf(
                        "type" to "online_users_update",
                        "data" to onlineUsers,
                        "message" to "Requested online users list"
                    )

                    session.remote.sendString(gson.toJson(onlineUsersMessage))
                    println("Sent requested online users list to user ${user.id}")
                }
                else -> {
                    // Handle other message types (WebRTC signaling, etc.)
                    val signalingMessage = gson.fromJson(message, SignalingMessage::class.java)

                    if (signalingMessage.type == "offer" ||
                        signalingMessage.type == "answer" ||
                        signalingMessage.type == "candidate" ||
                        signalingMessage.type == "chat_message" ||
                        signalingMessage.type == "file_metadata"||
                        signalingMessage.type == "aes_key_exchange"
                    ) {

                        if(signalingMessage.type == "aes_key_exchange")
                        {
                            print("Sending encrypted aes key from backend to : ${signalingMessage.targetUserId}");
                            print("encrypted aes key:${signalingMessage.payload}");
                        }
                        val fullSignalingMessage = signalingMessage.copy(
                            senderUserId = user.id,
                            senderUsername = "${user.firstName} ${user.lastName}"
                        )
                        val messageToSend = gson.toJson(fullSignalingMessage)
                        print("DEBUG: ${messageToSend}");

                        signalingMessage.targetUserId?.let { targetId ->
                            val targetSession = sessionController.getSession(targetId)
                            if (targetSession != null && targetSession.isOpen) {
                                targetSession.remote.sendString(messageToSend)
                                println("Relayed '${signalingMessage.type}' from user ${user.id} to $targetId.")
                            } else {
                                val errorMessage = mapOf(
                                    "type" to "error",
                                    "message" to "User $targetId is offline or unavailable."
                                )
                                session.remote.sendString(gson.toJson(errorMessage))
                            }
                        } ?: run {
                            val errorMessage = mapOf(
                                "type" to "error",
                                "message" to "Missing targetUserId in signaling message."
                            )
                            session.remote.sendString(gson.toJson(errorMessage))
                        }
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("Error parsing WebSocket message from user ${user.id}: ${e.message}")
            e.printStackTrace()
            val errorMessage = mapOf(
                "type" to "error",
                "message" to "Invalid message format received."
            )
            session.remote.sendString(gson.toJson(errorMessage))
        }
    }

    @OnWebSocketClose
    fun onClose(statusCode: Int, reason: String?) {
        println("User ${user.id} WebSocket disconnected. Status: $statusCode, Reason: $reason")
        sessionController.removeSession(user.id)

        // Broadcast user offline to others
        val userOfflineMessage = mapOf(
            "type" to "user_offline",
            "data" to mapOf(
                "id" to user.id,
                "firstName" to user.firstName,
                "lastName" to user.lastName,
                "email" to user.email,
                "phoneNo" to user.phoneNo,
                "publicKeyPem" to user.publicKeyPem,
                "fullName" to "${user.firstName} ${user.lastName}"
            ),
            "message" to "${user.firstName} ${user.lastName} is now offline."
        )

        sessionController.broadcastMessage(
            SignalingMessage(
                type = "user_offline",
                senderUserId = user.id,
                senderUsername = "${user.firstName} ${user.lastName}",
                message = gson.toJson(userOfflineMessage)
            )
        )
    }

    @OnWebSocketError
    fun onError(cause: Throwable?) {
        System.err.println("User ${user.id} WebSocket error: ${cause?.message}")
        cause?.printStackTrace()
        sessionController.removeSession(user.id)

        // Broadcast user offline due to error
        val userOfflineMessage = mapOf(
            "type" to "user_offline",
            "data" to mapOf(
                "id" to user.id,
                "firstName" to user.firstName,
                "lastName" to user.lastName,
                "email" to user.email,
                "phoneNo" to user.phoneNo,
                "publicKeyPem" to user.publicKeyPem,
                "fullName" to "${user.firstName} ${user.lastName}"
            ),
            "message" to "${user.firstName} ${user.lastName} went offline due to an error."
        )

        sessionController.broadcastMessage(
            SignalingMessage(
                type = "user_offline",
                senderUserId = user.id,
                senderUsername = "${user.firstName} ${user.lastName}",
                message = gson.toJson(userOfflineMessage)
            )
        )
    }
}