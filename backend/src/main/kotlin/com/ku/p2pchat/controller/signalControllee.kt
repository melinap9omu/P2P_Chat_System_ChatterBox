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
import org.eclipse.jetty.websocket.server.JettyWebSocketServlet
import org.eclipse.jetty.websocket.server.JettyWebSocketServletFactory
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userLogin


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
            val userid = httpSession?.getAttribute("userId") as? Int
        }

    }
}







