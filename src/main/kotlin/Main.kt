package org.example.com.ku.p2pchat

import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder

fun main() {
    // Create a Jetty server on port 8080
    val server = Server(8080)

    // Set up the context ("/" means root)
    val context = ServletContextHandler(ServletContextHandler.SESSIONS)
    context.contextPath = "/"

    // Register the register servlet
    val registerServlet = ServletHolder(registerControler())
    context.addServlet(registerServlet, "/register")

    // Attach context to server
    server.handler = context

    println("🚀 Server started at http://localhost:8080")
    server.start()
    server.join()
}
