package org.example.com.ku.p2pchat

import com.google.gson.Gson
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.daoImple.registerDaoimp
import org.example.com.ku.p2pchat.model.userRegister
import at.favre.lib.crypto.bcrypt.BCrypt
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.Paths
import java.util.*
import kotlin.random.Random

@WebServlet("/register")
class registerController : HttpServlet() {

    private val gson = Gson()
    private val uploadDir = "uploads/profile_images/" // Directory to store profile images

    init {
        // Create upload directory if it doesn't exist
        File(uploadDir).mkdirs()
    }

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer
        val dao = registerDaoimp()
        var responseMap: Map<String, Any>

        try {
            val reader = req.reader
            val incomingRequest = gson.fromJson(reader, userRegister::class.java)

            println("DEBUG: Backend received incomingRequest: $incomingRequest")

            // Input validation
            if (incomingRequest.password.isNullOrBlank()) {
                out.write(gson.toJson(mapOf("success" to false, "message" to "❌ Password cannot be empty.")))
                return
            }

            if (incomingRequest.password != incomingRequest.rePassword) {
                out.write(gson.toJson(mapOf("success" to false, "message" to "❌ Passwords do not match.")))
                return
            }

            // Hash the password
            val hashedPassword = BCrypt.withDefaults().hashToString(12, incomingRequest.password.toCharArray())

            // Handle profile image
            var profileImagePath: String? = null
            var profileBackgroundColor: String? = null

            if (!incomingRequest.profileImageBase64.isNullOrEmpty()) {
                // Save uploaded image
                profileImagePath = saveProfileImage(incomingRequest.profileImageBase64)
            } else {
                // Generate random background color for initials
                profileBackgroundColor = generateRandomColor()
            }

            val userToRegister = user(
                id = 0, // Always 0 — will be updated after insertion
                firstName = incomingRequest.firstName,
                lastName = incomingRequest.lastName,
                phoneNo = incomingRequest.phoneNo,
                email = incomingRequest.email,
                hashPassword = hashedPassword,
                publicKeyPem = null,
                profileImagePath = profileImagePath,
                profileBackgroundColor = profileBackgroundColor
            )

            val isRegistered = dao.registerUser(userToRegister)

            if (isRegistered) {
                req.session.setAttribute("userId", userToRegister.id)

                responseMap = mapOf(
                    "success" to true,
                    "message" to "✅ ${userToRegister.firstName} registered successfully!",
                    "data" to mapOf(
                        "user" to mapOf(
                            "id" to userToRegister.id,
                            "firstName" to userToRegister.firstName,
                            "lastName" to userToRegister.lastName,
                            "phoneNo" to userToRegister.phoneNo,
                            "email" to userToRegister.email,
                            "profileImagePath" to userToRegister.profileImagePath,
                            "profileBackgroundColor" to userToRegister.profileBackgroundColor
                        )
                    )
                )
            } else {
                responseMap = mapOf("success" to false, "message" to "❌ Registration failed. Email might already exist.")
            }

            out.write(gson.toJson(responseMap))

        } catch (e: Exception) {
            e.printStackTrace()
            responseMap = mapOf("success" to false, "message" to "❌ Internal Server Error: ${e.message}")
            out.write(gson.toJson(responseMap))
        } finally {
            out.flush()
            out.close()
        }
    }

    private fun saveProfileImage(base64Image: String): String? {
        return try {
            // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
            val base64Data = if (base64Image.contains(",")) {
                base64Image.split(",")[1]
            } else {
                base64Image
            }

            // Decode base64 to bytes
            val imageBytes = Base64.getDecoder().decode(base64Data)

            // Generate unique filename
            val fileName = "profile_${System.currentTimeMillis()}_${Random.nextInt(1000)}.jpg"
            val filePath = uploadDir + fileName

            // Write to file
            FileOutputStream(filePath).use { fos ->
                fos.write(imageBytes)
            }

            println("Profile image saved: $filePath")
            filePath
        } catch (e: Exception) {
            println("Error saving profile image: ${e.message}")
            e.printStackTrace()
            null
        }
    }

    private fun generateRandomColor(): String {
        val colors = listOf(
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
            "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
            "#F8C471", "#82E0AA", "#F1948A", "#85C1E9", "#D7BDE2"
        )
        return colors[Random.nextInt(colors.size)]
    }
}