package org.example.com.ku.p2pchat

import com.ku.p2pchat.database.DatabaseConnection
import jakarta.servlet.DispatcherType
import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import org.eclipse.jetty.websocket.server.config.JettyWebSocketServletContainerInitializer
//import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.PublicKeyController

import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.forgetPasswordController
//import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.signalControllee
import org.example.com.ku.p2pchat.com.ku.p2pchat.database.databaseTable
import org.eclipse.jetty.servlets.CrossOriginFilter
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
//import org.example.com.ku.p2pchat.controller.UserLoginController
import java.util.EnumSet

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

        // Enable CORS
        val cors = context.addFilter(CrossOriginFilter::class.java, "/*", EnumSet.of(DispatcherType.REQUEST))
        cors.setInitParameter(CrossOriginFilter.ALLOWED_ORIGINS_PARAM, "*") // Allow all origins (use with caution!)
        cors.setInitParameter(CrossOriginFilter.ALLOWED_METHODS_PARAM, "GET,POST,HEAD,OPTIONS")
        cors.setInitParameter(CrossOriginFilter.ALLOWED_HEADERS_PARAM, "X-Requested-With,Content-Type,Accept,Origin")

        // Register the register servlet
        val registerServlet = ServletHolder(RegisterController())
        context.addServlet(registerServlet, "/register")

        val loginServlet = ServletHolder(userLoginController())
        context.addServlet(loginServlet, "/login")

        val forgetServlet = ServletHolder(forgetPasswordController())
        context.addServlet(forgetServlet, "/forgetPassword")


        // Register the WebSocket servlet
//        context.addServlet(signalControllee::class.java, "/signal")


            // Attach context to server
        server.handler = context

//// Add your servlets
//        context.addServlet(ServletHolder(PublicKeyController()), "/public-key/*")


        // Configure WebSocket for signalControllee
//        JettyWebSocketServletContainerInitializer.configure(context) { servletContext, container ->
//            container.addMapping("/signal/*", signalControllee::class.java)
//        }


        println("🚀 Server started at http://localhost:8080")
        server.start()
        println("Jetty server started on port 8080")
        server.join()
    }catch(e: Exception){
        println("❌ Failed to connect or initialize DB: ${e.message}")

    }
}
