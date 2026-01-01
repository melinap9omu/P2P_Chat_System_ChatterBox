package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import com.google.gson.Gson
import jakarta.servlet.annotation.MultipartConfig
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import jakarta.servlet.http.Part
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.util.Base64
import java.util.UUID

@WebServlet("/profile-image")
@MultipartConfig(
    maxFileSize = 5 * 1024 * 1024, // 5MB max file size
    maxRequestSize = 10 * 1024 * 1024, // 10MB max request size
    fileSizeThreshold = 1024 * 1024 // 1MB threshold for storing in memory vs disk
)
class ProfileImageController : HttpServlet() {
    private val gson = Gson()
    private lateinit var userDao: userLogindaoImp

    // Directory to store profile images
    private val baseUploadsDirectory = "C:\\Users\\Melina\\P2P_Chat_System_ChatterBox\\backend"
    private val allowedImageTypes = setOf("image/jpeg", "image/png", "image/gif", "image/webp")
    private val maxImageSize = 5 * 1024 * 1024 // 5MB

    override fun init() {
        super.init()
        userDao = userLogindaoImp()
    }

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        try {
            val userIdParam = req.getParameter("userId")
            if (userIdParam == null || userIdParam.toIntOrNull() == null) {
                resp.sendError(HttpServletResponse.SC_BAD_REQUEST, "Missing or invalid userId parameter")
                return
            }
            val userId = userIdParam.toInt()

            println("DEBUG: Received request for userId: $userId")

            // Get the relative image path from the database
            val imagePathFromDb = userDao.getProfileImagePath(userId)
            if (imagePathFromDb.isNullOrBlank()) {
                println("DEBUG: No image path found in database for user $userId")
                resp.sendError(HttpServletResponse.SC_NOT_FOUND, "Profile image not found")
                return
            }

            // Construct the full absolute file path
            val imageFile = File(baseUploadsDirectory, imagePathFromDb)
            println("DEBUG: Looking for image file at: ${imageFile.absolutePath}")

            if (!imageFile.exists() || !imageFile.isFile) {
                println("DEBUG: Image file not found on disk: ${imageFile.absolutePath}")
                resp.sendError(HttpServletResponse.SC_NOT_FOUND, "Profile image not found")
                return
            }

            // Set content type based on file extension
            val mimeType = servletContext.getMimeType(imageFile.name) ?: "image/jpeg"
            resp.contentType = mimeType
            resp.setContentLength(imageFile.length().toInt())

            // Stream the image file to the response
            FileInputStream(imageFile).use { fileInputStream ->
                val outputStream = resp.outputStream
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (fileInputStream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                outputStream.flush()
            }

            println("DEBUG: Successfully served profile image for user $userId from path: $imagePathFromDb")

        } catch (e: Exception) {
            println("ERROR: Exception in doGet: ${e.message}")
            e.printStackTrace()
            try {
                resp.sendError(HttpServletResponse.SC_INTERNAL_SERVER_ERROR, "An error occurred while retrieving the image.")
            } catch (ioe: IOException) {
                println("ERROR: Failed to send error response: ${ioe.message}")
            }
        }
    }

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        try {
            val session = req.getSession(false)
            val userId = session?.getAttribute("userId") as? Int
            if (userId == null) {
                resp.status = HttpServletResponse.SC_UNAUTHORIZED
                out.write(gson.toJson(mapOf("success" to false, "message" to "User not authenticated")))
                return
            }

            val user = userDao.findUserById(userId)
            if (user == null) {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "User not found")))
                return
            }

            val contentType = req.contentType
            when {
                contentType?.startsWith("multipart/form-data") == true -> {
                    handleMultipartUpload(req, resp, userId)
                }
                contentType?.startsWith("application/json") == true -> {
                    handleBase64Upload(req, resp, userId)
                }
                else -> {
                    resp.status = HttpServletResponse.SC_BAD_REQUEST
                    out.write(gson.toJson(mapOf(
                        "success" to false,
                        "message" to "Unsupported content type. Use multipart/form-data or application/json"
                    )))
                }
            }
        } catch (e: Exception) {
            System.err.println("Error uploading profile image: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Server error: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }

    override fun doDelete(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json"
        val out = resp.writer

        try {
            val session = req.getSession(false)
            val userId = session?.getAttribute("userId") as? Int
            if (userId == null) {
                resp.status = HttpServletResponse.SC_UNAUTHORIZED
                out.write(gson.toJson(mapOf("success" to false, "message" to "User not authenticated")))
                return
            }

            val imagePathFromDb = userDao.getProfileImagePath(userId)
            if (imagePathFromDb.isNullOrBlank()) {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "Profile image not found")))
                return
            }

            val imageFile = File(baseUploadsDirectory, imagePathFromDb)
            if (imageFile.exists() && imageFile.isFile) {
                val deleted = imageFile.delete()
                if (deleted) {
                    userDao.deleteProfileImagePath(userId)
                    resp.status = HttpServletResponse.SC_OK
                    out.write(gson.toJson(mapOf("success" to true, "message" to "Profile image deleted successfully")))
                    println("DEBUG: Profile image deleted for user $userId")
                } else {
                    resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                    out.write(gson.toJson(mapOf("success" to false, "message" to "Failed to delete profile image")))
                }
            } else {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                out.write(gson.toJson(mapOf("success" to false, "message" to "Profile image not found on disk")))
            }
        } catch (e: Exception) {
            System.err.println("Error deleting profile image: ${e.message}")
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Server error: ${e.message}")))
        } finally {
            out.flush()
            out.close()
        }
    }

    private fun handleMultipartUpload(req: HttpServletRequest, resp: HttpServletResponse, userId: Int) {
        val imagePart: Part? = req.getPart("image")
        if (imagePart == null) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "No image file provided")))
            return
        }
        if (imagePart.size > maxImageSize) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Image file too large. Maximum size is 5MB")))
            return
        }
        val contentType = imagePart.contentType
        if (contentType !in allowedImageTypes) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Invalid image format. Allowed: JPEG, PNG, GIF, WebP")))
            return
        }

        deleteExistingUserImage(userId)

        val fileExtension = getFileExtensionFromContentType(contentType)
        val relativeDirectory = "uploads/profile_images"
        val fullRelativePath = "$relativeDirectory/profile_${userId}_${System.currentTimeMillis()}_${UUID.randomUUID()}.$fileExtension"
        val imageFile = File(baseUploadsDirectory, fullRelativePath)

        imageFile.parentFile.mkdirs()
        imagePart.inputStream.use { input ->
            FileOutputStream(imageFile).use { output ->
                input.copyTo(output)
            }
        }

        userDao.updateProfileImagePath(userId, fullRelativePath)

        resp.status = HttpServletResponse.SC_OK
        resp.writer.write(gson.toJson(mapOf(
            "success" to true,
            "message" to "Profile image uploaded successfully",
            "imageUrl" to "/profile-image?userId=$userId"
        )))
        println("DEBUG: Profile image uploaded successfully for user $userId: ${imageFile.name}")
    }

    private fun handleBase64Upload(req: HttpServletRequest, resp: HttpServletResponse, userId: Int) {
        val requestBody = req.reader.readText()
        if (requestBody.isBlank()) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Empty request body")))
            return
        }
        val requestData = try {
            gson.fromJson(requestBody, Map::class.java) as Map<String, Any>
        } catch (e: Exception) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Invalid JSON format")))
            return
        }
        val base64Image = requestData["profileImageBase64"] as? String
        if (base64Image.isNullOrBlank()) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "profileImageBase64 field is required")))
            return
        }
        try {
            val (mimeType, base64Data) = parseDataUrl(base64Image)
            if (mimeType !in allowedImageTypes) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Invalid image format. Allowed: JPEG, PNG, GIF, WebP")))
                return
            }
            val imageBytes = Base64.getDecoder().decode(base64Data)
            if (imageBytes.size > maxImageSize) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Image file too large. Maximum size is 5MB")))
                return
            }

            deleteExistingUserImage(userId)

            val fileExtension = getFileExtensionFromContentType(mimeType)
            val relativeDirectory = "uploads/profile_images"
            val fullRelativePath = "$relativeDirectory/profile_${userId}_${System.currentTimeMillis()}_${UUID.randomUUID()}.$fileExtension"
            val imageFile = File(baseUploadsDirectory, fullRelativePath)

            imageFile.parentFile.mkdirs()
            Files.write(imageFile.toPath(), imageBytes)

            userDao.updateProfileImagePath(userId, fullRelativePath)

            resp.status = HttpServletResponse.SC_OK
            resp.writer.write(gson.toJson(mapOf(
                "success" to true,
                "message" to "Profile image uploaded successfully",
                "imageUrl" to "/profile-image?userId=$userId"
            )))
            println("DEBUG: Profile image uploaded successfully for user $userId: ${imageFile.name}")
        } catch (e: IllegalArgumentException) {
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            resp.writer.write(gson.toJson(mapOf("success" to false, "message" to "Invalid base64 image data")))
        }
    }

    private fun parseDataUrl(dataUrl: String): Pair<String, String> {
        if (!dataUrl.startsWith("data:")) {
            return Pair("image/jpeg", dataUrl)
        }
        val parts = dataUrl.split(",", limit = 2)
        if (parts.size != 2) {
            throw IllegalArgumentException("Invalid data URL format")
        }
        val header = parts[0]
        val base64Data = parts[1]
        val mimeType = header.substringAfter("data:").substringBefore(";")
        return Pair(mimeType, base64Data)
    }

    private fun deleteExistingUserImage(userId: Int) {
        val imagePathFromDb = userDao.getProfileImagePath(userId)
        if (!imagePathFromDb.isNullOrBlank()) {
            val existingImage = File(baseUploadsDirectory, imagePathFromDb)
            if (existingImage.exists() && existingImage.isFile) {
                existingImage.delete()
                println("DEBUG: Deleted existing profile image for user $userId")
            }
        }
    }

    private fun getFileExtensionFromContentType(contentType: String): String {
        return when (contentType) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/gif" -> "gif"
            "image/webp" -> "webp"
            else -> "jpg"
        }
    }
}
