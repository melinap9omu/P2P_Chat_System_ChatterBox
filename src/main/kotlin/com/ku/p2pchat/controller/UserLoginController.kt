package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.daoImple.userLogindaoImp

import java.io.IOException


@WebServlet("/login")
class userLoginController: HttpServlet() {

    private val gson = Gson()
    private val dao = userLogindaoImp()

    data class LoginRequest(val number: String?, val password: String?)

    @Throws(IOException::class)
    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        println("Login doPost called")

        resp.contentType = "application/json"
        resp.setHeader("Access-Control-Allow-Origin", "*")
        resp.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        resp.setHeader("Access-Control-Allow-Headers", "Content-Type")
        val out = resp.writer

        try {
            val reader = req.reader
            val loginRequest = gson.fromJson(reader, LoginRequest::class.java)

            println("Login request received: $loginRequest")

            if (loginRequest.number.isNullOrBlank() || loginRequest.password.isNullOrBlank()) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                val json = gson.toJson(mapOf("success" to false, "message" to "Number and password required"))
                out.write(json)
                return
            }

            val user = dao.login(loginRequest.number, loginRequest.password)
            println("Login user result: $user")

            val response = if (user != null) {
                println("Sending success response with user data")
                mapOf(
                    "success" to true,
                    "message" to "Login successful",
                    "user" to mapOf(
                        "number" to user.number,
                        "first_name" to user.firstname,
                        "last_name" to user.lastname
                    )
                )
            } else {
                mapOf("success" to false, "message" to "Invalid number or password, try again")
            }

            println("Response JSON: ${gson.toJson(response)}")
            resp.status = HttpServletResponse.SC_OK
            out.write(gson.toJson(response))

        } catch (e: Exception) {
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Error: ${e.message}")))
            e.printStackTrace()
        } finally {
            out.flush()
        }
    }
}