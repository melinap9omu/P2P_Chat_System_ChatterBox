package org.example.com.ku.p2pchat

import com.ku.p2pchat.database.DatabaseConnection
import jakarta.servlet.DispatcherType
import jakarta.servlet.MultipartConfigElement // Correct import for MultipartConfigElement
import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import org.eclipse.jetty.servlets.CrossOriginFilter
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.forgetPasswordController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.imageController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
import org.example.com.ku.p2pchat.com.ku.p2pchat.database.databaseTable
import java.util.EnumSet

fun main() {
    try {
        // Connect to the database and initialize
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

        // Create MultipartConfigElement with temp directory and limits (adjust as needed)
        val multipartConfig = MultipartConfigElement(
            System.getProperty("java.io.tmpdir") ?: "/tmp", // Temporary directory for file uploads
            10_485_760, // max file size (10MB)
            20_971_520, // max request size (20MB)
            1024 * 1024  // file size threshold after which file will be written to disk (1MB)
        )

        // Register the image servlet and apply the MultipartConfigElement directly
        val imageServlet = ServletHolder(imageController::class.java) // Use class reference
        imageServlet.registration.setMultipartConfig(multipartConfig) // Correctly apply multipart config
        context.addServlet(imageServlet, "/user/image")

        // Attach context to server
        server.handler = context

        println("🚀 Server started at http://localhost:8080")
        server.start()
        println("Jetty server started on port 8080")
        server.join()
    } catch(e: Exception) {
        println("❌ Failed to connect or initialize DB: ${e.message}")
        e.printStackTrace() // Print full stack trace for better debugging
    }
}
