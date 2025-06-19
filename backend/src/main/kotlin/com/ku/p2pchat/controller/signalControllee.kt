package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import org.eclipse.jetty.websocket.api.Session
import jakarta.servlet.annotation.WebServlet
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect
import org.eclipse.jetty.websocket.api.annotations.WebSocket
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpSession
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketMessage
import org.eclipse.jetty.websocket.server.JettyWebSocketServlet
import org.eclipse.jetty.websocket.server.JettyWebSocketServletFactory
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.SignalingMessage


import java.util.UUID

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
class SignalingSocket (private val user: user){
    private lateinit var session: Session
    private val gson=Gson()

    @OnWebSocketConnect
    fun onConnect(session:Session){
        this.session = session
        sessionController.addSession(user,session)
        println("user ${user.email} (ID:${user.id}) WebSocket connected")
    }

    @OnWebSocketMessage
    fun onMessage(message: String?){
        if (message==null){
            return
        }
        println("Received message from User ${user.id}:$message")

        try{
            val signalingMessage = gson.fromJson(message, SignalingMessage::class.java)
            val fullSignalingMessage = signalingMessage.copy(senderUserId = user.id)
            val messageToSend = gson.toJson(fullSignalingMessage)

            signalingMessage.targetUserId?.let{targetId->
                val targetSession= sessionController.getSession(targetId)
                if (targetSession !=null && targetSession.isOpen){
                    targetSession.remote.sendString(messageToSend)
                    println("Relayed '${signalingMessage.type} from user ${user.id}")
                }
                else{
                    println("Target user $targetId is offline or session not open. Cannot relay '${signalingMessage.type}' from user ${user.id}")
                }
            } ?:run {
                println("Received messge from user ${user.id} without targetUserId: $message")
                this.session.remote.sendString(gson.toJson(mapOf("type" to "error", "message" to "Missing targetUserId in signaling message.")))
            }

        }
        catch(e: Exception){
            System.err.println("Error parsing or relaying webSocket mesaage from user ${user.id}")
            e.printStackTrace()
            this.session.remote.sendString(gson.toJson(mapOf("type" to "error", "message" to "Invalid message format")))
        }

    }





}





