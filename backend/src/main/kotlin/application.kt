package org.example.com.ku.p2pchat

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.serialization.kotlinx.json.*
import org.example.com.ku.p2pchat.controller.userRoutes
import org.example.com.ku.p2pchat.database.DatabaseConfig
import org.example.com.ku.p2pchat.service.UserService
import org.example.com.ku.p2pchat.websocket.SignalingServer
import java.time.Duration

fun main() {
    DatabaseConfig.init()
    embeddedServer(Netty, port = 8080, host = "0.0.0.0") {
        configureRouting()
    }.start(wait = true)
}

fun Application.configureRouting() {
    install(ContentNegotiation) {
        json()
    }
    
    install(CORS) {
        anyHost()
        allowHeader("Content-Type")
        allowMethod(io.ktor.http.HttpMethod.Get)
        allowMethod(io.ktor.http.HttpMethod.Post)
        allowMethod(io.ktor.http.HttpMethod.Put)
        allowMethod(io.ktor.http.HttpMethod.Delete)
    }
    
    install(WebSockets) {
        pingPeriod = Duration.ofSeconds(15)
        timeout = Duration.ofSeconds(15)
        maxFrameSize = Long.MAX_VALUE
        masking = false
    }
    
    val userService = UserService()
    val signalingServer = SignalingServer()
    
    routing {
        userRoutes(userService)
        
        webSocket("/ws/{userId}") {
            val userId = call.parameters["userId"]?.toIntOrNull()
            if (userId != null) {
                signalingServer.handleConnection(this, userId)
            } else {
                close(CloseReason(CloseReason.Codes.VIOLATED_POLICY, "Invalid user ID"))
            }
        }
    }
}