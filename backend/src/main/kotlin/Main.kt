package org.example.com.ku.p2pchat

import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.FilterHolder
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import jakarta.servlet.DispatcherType
import java.util.EnumSet
import java.net.InetSocketAddress
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.ChangePasswordController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.PublicKeyController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.ProfileImageController

// Remove or correct this if signalControllee is a real class you've omitted
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.signalControllee // <- If this isn't a defined class, remove it.
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.OnlineUsersController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.WebSocketServlet

import org.example.com.ku.p2pchat.registerController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.UserListServlet
import org.example.p2pchat.filter.AuthFilter
import org.eclipse.jetty.servlets.CrossOriginFilter

import org.example.com.ku.p2pchat.com.ku.p2pchat.database.DatabaseManager

import org.eclipse.jetty.websocket.server.config.JettyWebSocketServletContainerInitializer

fun main() {

    DatabaseManager.createTables()
    val server = Server(InetSocketAddress("0.0.0.0", 8080))
    // Set up the context ("/" means root)
    val context = ServletContextHandler(ServletContextHandler.SESSIONS)
    context.contextPath = "/"

    // THIS IS CRUCIAL FOR WEBSOCKETS
    // Configure WebSocket support for the context
    JettyWebSocketServletContainerInitializer.configure(context, null)

    // Configure the CORS FilterHolder - MORE PERMISSIVE FOR DEVELOPMENT
    val corsFilterHolder = FilterHolder(CrossOriginFilter::class.java).apply {
        // Allow all localhost origins for development
        setInitParameter(CrossOriginFilter.ALLOWED_ORIGINS_PARAM, "*")
        // OR use this more specific pattern for localhost:
        // setInitParameter(CrossOriginFilter.ALLOWED_ORIGINS_PARAM, "http://localhost:*,https://localhost:*")

        setInitParameter(CrossOriginFilter.ALLOWED_METHODS_PARAM, "GET,POST,PUT,DELETE,HEAD,OPTIONS")
        setInitParameter(CrossOriginFilter.ALLOWED_HEADERS_PARAM, "X-Requested-With,Content-Type,Accept,Origin,Authorization,Cache-Control,Pragma")
        setInitParameter(CrossOriginFilter.ALLOW_CREDENTIALS_PARAM, "true")
        setInitParameter(CrossOriginFilter.PREFLIGHT_MAX_AGE_PARAM, "1800")
    }

    // ADD THE CORS FILTER FIRST - This is crucial for proper CORS handling
    context.addFilter(corsFilterHolder, "/*", EnumSet.of(DispatcherType.REQUEST, DispatcherType.ASYNC))

    // Add the AuthFilter AFTER CORS filter
    context.addFilter(FilterHolder(AuthFilter()), "/*", EnumSet.of(DispatcherType.REQUEST, DispatcherType.ASYNC))

    // Register your servlets
    val registerServlet = ServletHolder(registerController())
    context.addServlet(registerServlet, "/register")

    val loginServlet= ServletHolder(userLoginController())
    context.addServlet(loginServlet,"/login")

    val publicKeyServlet= ServletHolder(PublicKeyController())
    context.addServlet(publicKeyServlet,"/public-key")

    // Handle the WebSocketServlet (your main WebSocket endpoint)
    val webSocketServletHolder = ServletHolder(WebSocketServlet()) // Correctly instantiate your WebSocketServlet
    context.addServlet(webSocketServletHolder, "/websocket") // Use the path defined by @WebServlet

    // If 'signalControllee' is genuinely another HTTP servlet for signaling (not a WebSocket), keep it and ensure it's defined:
    val signalServlet = ServletHolder(signalControllee()) // <-- Keep this ONLY if signalControllee is a defined class
    context.addServlet(signalServlet, "/signal") // <-- And its path, if different from /websocket

    val userListServlet= ServletHolder(UserListServlet())
    context.addServlet(userListServlet,"/users")

    val userOnlineUsersController = ServletHolder(OnlineUsersController())
    context.addServlet(userOnlineUsersController, "/users/online")


    val ChangePasswordController = ServletHolder(ChangePasswordController())
    context.addServlet(ChangePasswordController, "/change-password")


    val ProfileImageController = ServletHolder(ProfileImageController())
    context.addServlet(ProfileImageController, "/profile-image")

    server.handler = context // You need to set the context as the server's handler

    // Attach context to server
    try {
        server.start()
        println("🚀 Server started at http://localhost:8080")
        println("WebSockets available at ws://localhost:8080/websocket") // Correct WebSocket URL
        // If you keep the /signal servlet, you might also want to print its URL
        // println("Signal HTTP endpoint available at http://localhost:8080/signal")
        println("CORS enabled for all origins (development mode)")
        server.join() // Blocks current thread until the server stops
    } catch (e: Exception) {
        System.err.println("❌ Error starting server: ${e.message}")
        e.printStackTrace()
        server.destroy()
    }
}