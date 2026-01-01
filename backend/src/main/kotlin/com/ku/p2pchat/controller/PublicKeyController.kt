package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import  org.example.com.ku.p2pchat.com.ku.p2pchat.controller.sessionController;


@WebServlet("/public-key")
class PublicKeyController : HttpServlet() {
    private val gson = Gson()
    private lateinit var userDao: userLogindaoImp

    override fun init() {
        super.init()
        userDao = userLogindaoImp()
    }

    data class UpdatePublicKeyRequest(
        @SerializedName("userId") val userId: Int,
        @SerializedName("publicKeyPem") val publicKeyPem: String
    )
    data class GetPublicKeyRequest(
        @SerializedName(value="userid") val userId: Int
    )
    override fun doPut(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        try {



            val requestBodyJson = req.reader.readText()
            println("DEBUG: Incoming PUT /public-key request body: $requestBodyJson")

            val updateRequest = gson.fromJson(requestBodyJson, UpdatePublicKeyRequest::class.java)
            val publicKeyPemFromRequest = updateRequest.publicKeyPem
            val userIdFromRequestBody = updateRequest.userId // Get userId from the request body

            val session = req.getSession(false)
            val userIdFromSession = session?.getAttribute("userId") as? Int

            val finalUserId = userIdFromSession ?: userIdFromRequestBody
            if (finalUserId == 0) { // Check if userId is still missing or invalid after trying both sources
                resp.status = HttpServletResponse.SC_BAD_REQUEST // Or SC_UNAUTHORIZED
                out.write(gson.toJson(mapOf("success" to false, "message" to "User ID missing or invalid for public key update")))
                return
            }

            if (userIdFromSession != null && finalUserId != userIdFromSession) {
                resp.status = HttpServletResponse.SC_FORBIDDEN
                out.write(gson.toJson(mapOf("success" to false, "message" to "Forbidden: Cannot update another user's public key when authenticated.")))
                return
            }

            if (publicKeyPemFromRequest.isBlank()) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "Public Key cannot be empty")))
                return
            }

            val currentUser = userDao.findUserById(finalUserId)
            if (currentUser == null) {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "User with ID $finalUserId not found.")))
                return
            }

            val updatedUser = currentUser.copy(publicKeyPem = publicKeyPemFromRequest)
            val success = userDao.updateUserPublicKey(updatedUser)
            print("DEBUG:updated public key ${updatedUser}");

            if (success) {
                resp.status = HttpServletResponse.SC_OK
                out.write(gson.toJson(mapOf("success" to true, "message" to "Public Key uploaded successfully")))
            } else {
                resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                out.write(gson.toJson(mapOf("success" to false, "message" to "Failed to update public key in database")))
            }

        } catch (e: Exception) {
            System.err.println("Error processing public key update: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Server error: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }


    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        print("DEBUG: get http started ");

        try {
            val targetUserIdParam = req.getParameter("targetUserId")


            val session  = req.getSession(false)
            val userIdFromSession = session?.getAttribute("userId") as? Int

            val targetUserId: Int? = (targetUserIdParam?.toIntOrNull()?:userIdFromSession)
            if (targetUserId == null) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "Missing or invalid 'targetUserId' parameter")))
                return
            }

            val targetUser = userDao.findUserById(targetUserId)
            if (targetUser != null && !targetUser.publicKeyPem.isNullOrBlank()) {
                print("Sending ${targetUser} public key : ${targetUser.publicKeyPem}")
                out.write(gson.toJson(mapOf("success" to true, "publicKeyPem" to targetUser.publicKeyPem)))
            } else {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "Public key not found for user ID: $targetUserId")))
            }

        } catch (e: Exception) {
            System.err.println("Error retrieving public key: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Server error: ${e.message}")))
        } finally {
            out.close()
        }
    }
}
