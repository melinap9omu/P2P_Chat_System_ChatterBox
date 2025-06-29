package org.example.com.ku.p2pchat

import com.ku.p2pchat.database.DatabaseConnection
import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import org.eclipse.jetty.websocket.server.config.JettyWebSocketServletContainerInitializer

import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.SignalingWebSocket
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.forgetPasswordController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
import org.example.com.ku.p2pchat.com.ku.p2pchat.database.databaseTable

fun main() {

    try {
        // ✅ Connect to the database and initialize
        val connection = DatabaseConnection.getConnection()
        databaseTable.initializeDatabase(connection)
        println("✅ Database and tables initialized successfully")
        connection.close()

        // Create a Jetty server on port 8080
        val server = Server(8080)

        // Set up the context ("/" means root)
        val context = ServletContextHandler(ServletContextHandler.SESSIONS)
        context.contextPath = "/"

        // Register the register servlet
        val registerServlet = ServletHolder(registerControler())
        context.addServlet(registerServlet, "/register")

        val loginServlet = ServletHolder(userLoginController())
        context.addServlet(loginServlet, "/login")

        val forgetServlet = ServletHolder(forgetPasswordController())
        context.addServlet(forgetServlet, "/forgetPassword")





        // Attach context to server
        server.handler = context

        JettyWebSocketServletContainerInitializer.configure(context) { _, container ->
            container.addMapping("/signaling", SignalingWebSocket::class.java)
        }

        println("🚀 Server started at http://localhost:8080")
        println("🔌 WebSocket available at ws://localhost:8080/signaling")
        server.start()
        server.join()
    }catch(e: Exception){
        println("❌ Failed to connect or initialize DB: ${e.message}")

    }
}
