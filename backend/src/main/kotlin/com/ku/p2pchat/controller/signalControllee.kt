package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import org.eclipse.jetty.websocket.api.Session
import jakarta.servlet.annotation.WebServlet
import org.eclipse.jetty.websocket.api.annotations.OnWebSocketConnect
import org.eclipse.jetty.websocket.api.annotations.WebSocket
import org.eclipse.jetty.websocket.server.JettyWebSocketServlet
import org.eclipse.jetty.websocket.server.JettyWebSocketServletFactory
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.util.UUID

@WebServlet("/signal")
class signalControllee : JettyWebSocketServlet(){
    override fun configure(factory: JettyWebSocketServletFactory) {
        factory.setCreator {_,_ ->
            val userId = UUID.randomUUID().toString()
            SignalingSocket(userId)
        }
    }
}

@WebSocket
class SignalingSocket(private val user: user) {
    private lateinit var session: Session
    private val gson=Gson()

    @OnWebSocketConnect
    fun onconnect(session:Session){
        this.session =session
        sessionController.addSession(user, session)
        session
    }


}
