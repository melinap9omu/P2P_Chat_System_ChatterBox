package org.example.com.ku.p2pchat.com.ku.p2pchat.controller


import org.eclipse.jetty.websocket.api.Session
import java.util.concurrent.ConcurrentHashMap
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import com.google.gson.Gson




object sessionController {
    private val activeSessions = ConcurrentHashMap<Int, Session>()
    private val activeUsers = ConcurrentHashMap<Int, user>()
    private val gson = Gson()

    fun addSession(user: user, session: Session) {
        activeSessions[user.id] = session
        activeUsers[user.id] = user
        println("User ${user.FirstName} (${user.id}) connected. Total users: ${activeSessions.size}")


    }

    fun removeSession(userId: Int) {
        activeSessions.remove(userId)
        activeUsers.remove(userId)
        println("User $userId disconnected. Total users: ${activeSessions.size}")
    }

    fun getSession(userId: Int): Session? {
        return activeSessions[userId]
    }

    fun getAllOnlineUsers(): List<user> {
        return activeUsers.values.toList()
    }

    fun getUserById(userId: Int): user? {
        return activeUsers[userId]
    }

    fun broadcastMessage(
        message: org.example.com.ku.p2pchat.com.ku.p2pchat.model.SignalingMessage,
        excludeUserId: Int? = null
    ) {
        val jsonMessage = gson.toJson(message)
        activeSessions.forEach { (userId, session) ->
            if (session.isOpen && userId != excludeUserId) {
                try {
                    session.remote.sendString(jsonMessage)
                    println("Broadcasted '${message.type}' to user ID: $userId") // Uncomment for more detailed logs
                } catch (e: Exception) {
                    System.err.println("Error broadcasting message to user $userId: ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }
}

