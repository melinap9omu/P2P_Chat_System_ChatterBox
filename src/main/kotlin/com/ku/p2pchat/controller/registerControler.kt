package org.example.com.ku.p2pchat

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.daoImple.registerDaoimp
import org.example.com.ku.p2pchat.model.userRegister

@WebServlet("/register")
class RegisterController : HttpServlet() {
    private val gson = Gson()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        resp.setHeader("Access-Control-Allow-Origin", "*")
        resp.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        resp.setHeader("Access-Control-Allow-Headers", "Content-Type")

        val out = resp.writer

        try {
            val reader = req.reader
            val user = gson.fromJson(reader, userRegister::class.java)

            if (user.password != user.rePassword) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                val json = gson.toJson(mapOf("success" to false, "message" to "❌ Passwords do not match"))
                out.write(json)
                return
            }

            val dao = registerDaoimp()
            val isRegistered = dao.registerUser(user)

            val result = if (isRegistered) {
                resp.status = HttpServletResponse.SC_OK
                mapOf("success" to true, "message" to "✅ ${user.firstname} registered successfully!")
            } else {
                resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                mapOf("success" to false, "message" to "❌ Registration failed")
            }

            out.write(gson.toJson(result))

        } catch (e: Exception) {
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            val errorJson = gson.toJson(mapOf("success" to false, "message" to "❌ Error: ${e.message}"))
            out.write(errorJson)
        } finally {
            out.flush()
            out.close()
        }
    }
}
