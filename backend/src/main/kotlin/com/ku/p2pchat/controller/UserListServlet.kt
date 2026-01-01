package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp // Your DAO
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user // Your User model

@WebServlet("/users")
class UserListServlet : HttpServlet() {

    private val userDao = userLogindaoImp() // Using your DAO
    private val gson = Gson()

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        resp.characterEncoding = "UTF-8"

        // The AuthFilter should handle authentication before this servlet is reached,
        // but we can still retrieve userId from session if needed for filtering self.
        val userId = req.session.getAttribute("userId") as? Int

        try {
            // Assuming your userLogindaoImp has a method to get all users
            val users = userDao.getAllUsers() // You need to add this method to your userLogindaoImp

            // Filter out the current user from the list
            val otherUsers = users.filter { it.id != userId }

            // Map to a simpler response structure for the frontend
            val userListResponse = otherUsers.map {
                mapOf(
                    "id" to it.id,
                    "firstName" to it.firstName,
                    "lastName" to it.lastName,
                    "phoneNo" to it.phoneNo,
                    "email" to it.email
                )
            }
            resp.status = HttpServletResponse.SC_OK
            resp.writer.write(gson.toJson(mapOf("users" to userListResponse))) // Matches Flutter's expectation
            println("User $userId requested user list. Sent ${userListResponse.size} users.")
        } catch (e: Exception) {
            println("Error fetching user list for user $userId: ${e.message}")
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Failed to fetch user list: ${e.message}")))
        }
    }
}