package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userLogin
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user

import java.io.IOException

@WebServlet("/login")
class userLoginController : HttpServlet() {
    private val gson = Gson()
    private val dao = userLogindaoImp()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        try {
            val loginRequest = gson.fromJson(req.reader, userLogin::class.java)

            if (loginRequest.email.isNullOrBlank() || loginRequest.password.isNullOrBlank()) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "❌ Email and Password are required.")))
                return
            }

            val authenticatedUser: user? = dao.login(loginRequest.email, loginRequest.password)

            val responseMap = if (authenticatedUser != null) {
                val session = req.getSession(true)
                session.setAttribute("userId", authenticatedUser.id)

                mapOf(
                    "success" to true,
                    "message" to "✅ Login successful",
                    "userId" to authenticatedUser.id,
                    "user" to mapOf(
                        "id" to authenticatedUser.id,
                        "firstName" to authenticatedUser.firstName,
                        "lastName" to authenticatedUser.lastName,
                        "email" to authenticatedUser.email,
                        "phoneNo" to authenticatedUser.phoneNo,
                        "publicKeyPem" to authenticatedUser.publicKeyPem // <-- ADDED THIS LINE

                    )
                )
            } else {
                mapOf("success" to false, "message" to "❌ Invalid credentials")
            }

            resp.status = HttpServletResponse.SC_OK
            out.write(gson.toJson(responseMap))

        } catch (e: Exception) {
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "❌ Server error: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }
}
