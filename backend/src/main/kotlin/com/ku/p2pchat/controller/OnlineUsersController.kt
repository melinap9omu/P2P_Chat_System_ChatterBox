package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user // Import your user model
import org.example.com.ku.p2pchat.com.ku.p2pchat.controller.sessionController

import java.io.IOException

@WebServlet("/users/online") // This annotation maps the servlet to the /users/online URL
class OnlineUsersController : HttpServlet() {
    private val gson = Gson()

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        resp.characterEncoding = "UTF-8" // Ensure proper character encoding
        val out = resp.writer

        try {
            // For a real-time "online" list, you'd integrate with your WebSocket session management.
            // For now, as per your DAO, we'll fetch ALL registered users.
            // In a production app, you'd filter this to only truly online users
            // by checking active WebSocket sessions or a database 'is_online' flag.
            val onlineUsers = sessionController.getAllOnlineUsers()

            // Filter out sensitive data like password_hash and public_key_pem
            val usersForFrontend = onlineUsers.map { user ->
                mapOf(
                    "id" to user.id,
                    "firstName" to user.FirstName, // Ensure these keys match Flutter's User.fromJson
                    "lastName" to user.LastName
                    // Do NOT send sensitive info like password_hash, public_key_pem, email, phoneNo here
                )
            }

            resp.status = HttpServletResponse.SC_OK
            out.write(gson.toJson(usersForFrontend))
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