package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import at.favre.lib.crypto.bcrypt.BCrypt
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import java.security.MessageDigest

@WebServlet("/change-password")
class ChangePasswordController : HttpServlet() {
    private val gson = Gson()
    private lateinit var userDao: userLogindaoImp

    override fun init() {
        super.init()
        userDao = userLogindaoImp()
    }

    data class ChangePasswordRequest(
        @SerializedName("oldPassword") val oldPassword: String,
        @SerializedName("newPassword") val newPassword: String,
        @SerializedName("confirmPassword") val confirmPassword: String
    )

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        try {
            // Get user ID from session
            val session = req.getSession(false)
            val userId = session?.getAttribute("userId") as? Int

            if (userId == null) {
                resp.status = HttpServletResponse.SC_UNAUTHORIZED
                out.write(gson.toJson(mapOf("success" to false, "message" to "User not authenticated")))
                return
            }

            // Parse request body
            val requestBodyJson = req.reader.readText()
            println("DEBUG: Change password request for user ID: $userId")

            val changePasswordRequest = gson.fromJson(requestBodyJson, ChangePasswordRequest::class.java)

            // Validate input
            if (changePasswordRequest.oldPassword.isBlank() ||
                changePasswordRequest.newPassword.isBlank() ||
                changePasswordRequest.confirmPassword.isBlank()) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "All password fields are required")))
                return
            }

            // Check if new password and confirm password match
            if (changePasswordRequest.newPassword != changePasswordRequest.confirmPassword) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "New password and confirm password do not match")))
                return
            }

            // Validate new password length
            if (changePasswordRequest.newPassword.length < 6) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "New password must be at least 6 characters long")))
                return
            }

            // Get current user
            val currentUser = userDao.findUserById(userId)
            if (currentUser == null) {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "User not found")))
                return
            }

            // Ensure stored password is not null
            if (currentUser.hashPassword.isNullOrBlank()) {
                resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                out.write(gson.toJson(mapOf("success" to false, "message" to "Stored password is invalid")))
                return
            }

            // Verify old password
            val verificationResult = BCrypt.verifyer().verify(
                changePasswordRequest.oldPassword.toCharArray(),
                currentUser.hashPassword!!.toCharArray()
            )

            if (!verificationResult.verified) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "Current password is incorrect")))
                return
            }

            // Hash the new password before saving
            val hashedNewPassword = BCrypt.withDefaults().hashToString(12, changePasswordRequest.newPassword.toCharArray())

            // Update password in database
            val success = userDao.updateUserPassword(userId, hashedNewPassword)

            if (success) {
                resp.status = HttpServletResponse.SC_OK
                out.write(gson.toJson(mapOf("success" to true, "message" to "Password updated successfully")))
                println("DEBUG: Password updated successfully for user ID: $userId")
            } else {
                resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                out.write(gson.toJson(mapOf("success" to false, "message" to "Failed to update password")))
            }

        } catch (e: Exception) {
            System.err.println("Error processing password change: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Server error: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }


}