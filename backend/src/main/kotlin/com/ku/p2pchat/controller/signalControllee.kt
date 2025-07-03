package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
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

                val authenticatedUser = User ?:userDao.findUserById(userId) //if User is null then fallback to userDao.getUserById


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
class SignalingSocket(private val user: user) { // The 'user' object should contain at least 'id', 'FirstName', and 'LastName'
    private lateinit var session: Session
    private val gson = Gson()

    @OnWebSocketConnect
    fun onConnect(session: Session) {
        this.session = session
        sessionController.addSession(user, session) // Use your 'sessionController' object
        println("User ${user.FirstName} (${user.id}) WebSocket connected.")

        // 1. Send the newly connected user the initial list of all currently online users
        val onlineUsers = sessionController.getAllOnlineUsers().map { onlineUser ->
            mapOf(
                "userId" to onlineUser.id,
                "username" to "${onlineUser.FirstName} ${onlineUser.LastName}" // Use First and Last Name
            )
        }.toList()

        val initialListMessage = SignalingMessage(
            type = "online_users_list",
            onlineUsers = onlineUsers,
            message = "Current online users list for ${user.FirstName} ${user.LastName}"
        )
        try {
            session.remote.sendString(gson.toJson(initialListMessage))
            println("Sent initial online users list to user ${user.id}.")
        } catch (e: Exception) {
            System.err.println("Error sending initial online users list to user ${user.id}: ${e.message}")
            e.printStackTrace()
        }

        // 2. Broadcast "user online" message to all *other* online users
        val userOnlineMessage = SignalingMessage(
            type = "user_online",
            senderUserId = user.id,
            senderUsername = "${user.FirstName} ${user.LastName}", // Use First and Last Name
            message = "${user.FirstName} ${user.LastName} is now online."
        )
        sessionController.broadcastMessage(
            userOnlineMessage,
            excludeUserId = user.id
        ) // Use your 'sessionController' object
    }

    @OnWebSocketMessage
    fun onMessage(message: String?) {
        if (message == null) {
            return
        }
        println("Received message from User ${user.id}: $message")

        try {
            val signalingMessage = gson.fromJson(message, SignalingMessage::class.java)

            // Handle various message types: WebRTC signaling, chat messages, etc.
            if (signalingMessage.type == "offer" ||
                signalingMessage.type == "answer" ||
                signalingMessage.type == "candidate" ||
                signalingMessage.type == "chat_message" ||
                signalingMessage.type == "file_metadata"
            ) {
                // Enrich the message with sender's info before relaying
                val fullSignalingMessage = signalingMessage.copy(
                    senderUserId = user.id,
                    senderUsername = "${user.FirstName} ${user.LastName}" // Use First and Last Name
                )
                val messageToSend = gson.toJson(fullSignalingMessage)

                signalingMessage.targetUserId?.let { targetId ->
                    val targetSession = sessionController.getSession(targetId) // Use your 'sessionController' object
                    if (targetSession != null && targetSession.isOpen) {
                        targetSession.remote.sendString(messageToSend)
                        println("Relayed '${signalingMessage.type}' from user ${user.id} to $targetId.")
                    } else {
                        System.err.println("Target user $targetId is offline or session not open. Cannot relay '${signalingMessage.type}' from user ${user.id}.")
                        this.session.remote.sendString(
                            gson.toJson(
                                SignalingMessage(
                                    type = "error",
                                    message = "User $targetId is offline or unavailable.",
                                    targetUserId = user.id
                                )
                            )
                        )
                    }
                } ?: run {
                    System.err.println("Received message from user ${user.id} without targetUserId for type '${signalingMessage.type}'. Message: $message")
                    this.session.remote.sendString(
                        gson.toJson(
                            SignalingMessage(
                                type = "error",
                                message = "Missing targetUserId in signaling message of type '${signalingMessage.type}'."
                            )
                        )
                    )
                }
            } else {
                System.err.println("Received unknown or unhandled signaling message type from user ${user.id}: ${signalingMessage.type}. Message: $message")
                this.session.remote.sendString(
                    gson.toJson(
                        SignalingMessage(
                            type = "error",
                            message = "Unknown message type: ${signalingMessage.type}"
                        )
                    )
                )
            }
        } catch (e: Exception) {
            System.err.println("Error parsing or relaying WebSocket message from user ${user.id}: ${e.message}")
            e.printStackTrace()
            this.session.remote.sendString(
                gson.toJson(
                    SignalingMessage(
                        type = "error",
                        message = "Invalid message format received."
                    )
                )
            )
        }
    }

    @OnWebSocketClose
    fun onClose(statusCode: Int, reason: String?) {
        println("User ${user.id} WebSocket disconnected. Status: $statusCode, Reason: $reason")
        sessionController.removeSession(user.id) // Use your 'sessionController' object

        // Broadcast "user offline" message to all remaining online users
        val userOfflineMessage = SignalingMessage(
            type = "user_offline",
            senderUserId = user.id,
            senderUsername = "${user.FirstName} ${user.LastName}", // Use First and Last Name
            message = "${user.FirstName} ${user.LastName} is now offline."
        )
        sessionController.broadcastMessage(userOfflineMessage) // Use your 'sessionController' object
    }

    @OnWebSocketError
    fun onError(cause: Throwable?) {
        System.err.println("User ${user.id} WebSocket error: ${cause?.message}")
        cause?.printStackTrace()
        sessionController.removeSession(user.id) // Use your 'sessionController' object

        // Broadcast "user offline" message due to error
        val userOfflineMessage = SignalingMessage(
            type = "user_offline",
            senderUserId = user.id,
            senderUsername = "${user.FirstName} ${user.LastName}", // Use First and Last Name
            message = "${user.FirstName} ${user.LastName} went offline due to an error."
        )
        sessionController.broadcastMessage(userOfflineMessage) // Use your 'sessionController' object
    }
}