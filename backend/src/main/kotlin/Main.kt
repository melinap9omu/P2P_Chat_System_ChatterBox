package org.example.com.ku.p2pchat

import org.eclipse.jetty.server.Server
import org.eclipse.jetty.servlet.ServletContextHandler
import org.eclipse.jetty.servlet.ServletHolder
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.userLoginController
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.chatController
fun main() {
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

    val chatServlet =ServletHolder(chatController())
        .context.addServlet(chatServlet, pathSpec="/Chat")

    // Attach context to server
    server.handler = context

    println("🚀 Server started at http://localhost:8080")
    server.start()
    server.join()
}
