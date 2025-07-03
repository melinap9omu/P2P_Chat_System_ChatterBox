package org.example.com.ku.p2pchat

import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.FilterHolder
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import jakarta.servlet.DispatcherType
import java.util.EnumSet

import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.PublicKeyController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.SignalingSocket
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.signalControllee
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.OnlineUsersController

import org.example.com.ku.p2pchat.registerController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.UserListServlet
import org.example.p2pchat.filter.AuthFilter




import org.example.com.ku.p2pchat.com.ku.p2pchat.database.DatabaseManager
fun main() {

    DatabaseManager.createTables()
    // Create a Jetty server on port 8080
    val server = Server(8080)

    // Set up the context ("/" means root)
    val context = ServletContextHandler(ServletContextHandler.SESSIONS)
    context.contextPath = "/"

    // Register the register servlet
    val registerServlet = ServletHolder(registerController())
    context.addServlet(registerServlet, "/register")

    val loginServlet= ServletHolder(userLoginController())
    context.addServlet(loginServlet,"/login")

    val publicKeyServlet= ServletHolder(PublicKeyController())
    context.addServlet(publicKeyServlet,"/public-key")


    val signalServlet= ServletHolder(signalControllee())
    context.addServlet(signalServlet,"/signal")

    val userListServlet= ServletHolder(UserListServlet())
    context.addServlet(userListServlet,"/login")

    val userOnlineUsersController = ServletHolder(OnlineUsersController())
    context.addServlet(userOnlineUsersController, "/users/online")

    val authFilter= FilterHolder(AuthFilter())
    context.addFilter(authFilter,"/*", EnumSet.of(DispatcherType.REQUEST))



    // Attach context to server
    try {
        server.start()
        println("🚀 Server started at http://localhost:8080")
        println("WebSockets available at ws://localhost:8080/signal")
        server.join() // Blocks current thread until the server stops
    } catch (e: Exception) {
        System.err.println("❌ Error starting server: ${e.message}")
        e.printStackTrace()
        server.destroy()
    }
}
