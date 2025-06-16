package org.example.com.ku.p2pchat.com.ku.p2pchat.controller


import org.eclipse.jetty.server.Authentication
import org.eclipse.jetty.util.security.Password
import org.eclipse.jetty.websocket.api.Session
import java.util.concurrent.ConcurrentHashMap
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user




object sessionController {
    private val activeSessions= ConcurrentHashMap<Int, Session > ()
    private val activeUsers = ConcurrentHashMap<Int , user>()

    fun addSession(user: user, session: Session){
        activeSessions[user.id] = session
        activeUsers[user.id]= user
        println("User ${user.username} (${user.id}) connected. Total users: ${activeSessions.size}")


    }

    fun removeSession(userId:Int) {
        activeSessions.remove(userId)
        activeUsers.remove(userId)
        println("User $userId disconnected. Total users: ${activeSessions.size}")
    }

    fun getSession(userId: Int):Session?{
        return activeSessions[userId]
    }

    fun getAllOnlineUsers():List<user> {
        return activeUsers.values.toList()
    }

    fun getUserById(userId: Int): user?{
        return activeUsers[userId]
    }


}