package org.example.com.ku.p2pchat

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.daoImple.registerDaoimp
import org.example.com.ku.p2pchat.model.userRegister

@WebServlet("/register")
class registerController : HttpServlet() {

    // Create a Gson object to convert JSON to Kotlin and vice versa
    private val gson = Gson()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        // Set the response type to JSON
        resp.contentType = "application/json"
        val out = resp.writer

        // Try to handle the request safely
        try {
            // Read the incoming JSON and convert it into a userRegister object
            val reader = req.reader
            val user = gson.fromJson(reader, userRegister::class.java)

            // Check if password and repassword match
            if (user.getPassword() != user.getRepassword()) {
                val json = gson.toJson(mapOf("success" to false, "message" to "❌ Passwords do not match"))
                out.write(json)
                return
            }


            // Call DAO to register the user
            val dao = registerDaoimp()
            val isRegistered = dao.registerUser(user)

            // Send success or failure response
            val result = if (isRegistered) {
                mapOf("success" to true, "message" to "✅ ${user.getFirstName()} registered successfully!")
            } else {
                mapOf("success" to false, "message" to "❌ Registration failed")
            }

            out.write(gson.toJson(result))

        } catch (e: Exception) {
            // In case of error
            val errorJson = gson.toJson(mapOf("success" to false, "message" to "❌ Error: ${e.message}"))
            out.write(errorJson)
        } finally {
            out.flush()
            out.close()
        }
    }
}
