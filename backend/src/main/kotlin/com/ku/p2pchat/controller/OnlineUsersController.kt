package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user // Import user model if needed, but OnlineUserData is used for mapping
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.WebSocketSessionController // Import WebSocketSessionController

import java.io.IOException

@WebServlet("/users/online")
class OnlineUsersController : HttpServlet() {
    private val gson = Gson()

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        resp.characterEncoding = "UTF-8"
        val out = resp.writer

        try {
            // Retrieve online users from the WebSocketSessionController
            val onlineUsers = WebSocketSessionController.getOnlineUsers()

            // Map the OnlineUserData objects to a format suitable for the frontend.
            // Note: The fields available are id, firstname, lastname, email, and fullName.
            val usersForFrontend = onlineUsers.map { onlineUserData ->
                mapOf(
                    "id" to onlineUserData.id,
                    "firstName" to onlineUserData.firstname,
                    "lastName" to onlineUserData.lastname,
                    "email" to onlineUserData.email,
                    "fullName" to onlineUserData.fullName
                )
            }

            resp.status = HttpServletResponse.SC_OK
            out.write(gson.toJson(usersForFrontend))
            println("DEBUG: HTTP Fetched ${usersForFrontend.size} online users via WebSocketSessionController")
        } catch (e: Exception) {
            System.err.println("Error fetching online users: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Error fetching users: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }
}