package org.example.com.ku.p2pchat.controller

import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import org.example.com.ku.p2pchat.model.*
import org.example.com.ku.p2pchat.service.UserService

fun Route.userRoutes(userService: UserService) {
    route("/api/users") {
        
        post("/register") {
            try {
                val userRegister = call.receive<userRegister>()
                val result = userService.registerUser(userRegister)
                if (result != null) {
                    call.respond(HttpStatusCode.Created, mapOf(
                        "success" to true,
                        "message" to "User registered successfully",
                        "user" to result
                    ))
                } else {
                    call.respond(HttpStatusCode.BadRequest, mapOf(
                        "success" to false,
                        "message" to "Registration failed"
                    ))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.BadRequest, mapOf(
                    "success" to false,
                    "message" to e.message
                ))
            }
        }
        
        post("/login") {
            try {
                val userLogin = call.receive<userLogin>()
                val result = userService.loginUser(userLogin)
                if (result != null) {
                    call.respond(HttpStatusCode.OK, mapOf(
                        "success" to true,
                        "message" to "Login successful",
                        "user" to result
                    ))
                } else {
                    call.respond(HttpStatusCode.Unauthorized, mapOf(
                        "success" to false,
                        "message" to "Invalid credentials"
                    ))
                }
            } catch (e: Exception) {
                call.respond(HttpStatusCode.BadRequest, mapOf(
                    "success" to false,
                    "message" to e.message
                ))
            }
        }
        
        get("/{id}") {
            val userId = call.parameters["id"]?.toIntOrNull()
            if (userId == null) {
                call.respond(HttpStatusCode.BadRequest, mapOf(
                    "success" to false,
                    "message" to "Invalid user ID"
                ))
                return@get
            }
            
            val user = userService.getUserById(userId)
            if (user != null) {
                call.respond(HttpStatusCode.OK, mapOf(
                    "success" to true,
                    "user" to user
                ))
            } else {
                call.respond(HttpStatusCode.NotFound, mapOf(
                    "success" to false,
                    "message" to "User not found"
                ))
            }
        }
    }
}