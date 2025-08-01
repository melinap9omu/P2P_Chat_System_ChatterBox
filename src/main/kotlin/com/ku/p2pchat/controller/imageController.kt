package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import jakarta.servlet.annotation.MultipartConfig
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.*
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userImagedaoImp
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userImage
import java.io.IOException


@WebServlet("/user/image")
@MultipartConfig
class imageController : HttpServlet() {

    private val dao = userImagedaoImp()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        println("🔄 [POST] /user/image hit")
        try {
            val userId = req.getParameter("userId")?.toIntOrNull()

            val part: Part? = req.getPart("image")

            if (userId == null || part == null) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                resp.writer.write("Missing userId or image file")
                return
            }

            //Read Image as ByteArray
            val inputStream = part.inputStream
            val imageBytes = inputStream.readBytes()

            // Insert or Update Image
            val existingImage = dao.getImageByUserId(userId)
            val image = userImage(userId = userId, imageData = imageBytes)

            val success = if (existingImage == null) {
                dao.insertImage(image)
            } else {
                dao.updateImage(image)
            }

            resp.contentType = "application/json"
            if (success) {
                resp.writer.write("""{"success": true}""")
            } else {
                resp.writer.write("""{"success": false, "message": "Database operation failed"}""")
            }

        } catch (e: Exception) {
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            resp.writer.write("""{"error": "${e.message}"}""")
        }
    }

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse) {
        println("📥 [GET] /user/image hit")
        try {
            val userId = req.getParameter("userId")?.toIntOrNull()
            if (userId == null) {
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                resp.writer.write("Missing userId")
                return
            }

            val image = dao.getImageByUserId(userId)
            if (image != null) {
                resp.contentType = "image/jpeg"
                resp.outputStream.write(image.imageData)
            } else {
                resp.status = HttpServletResponse.SC_NOT_FOUND
                resp.writer.write("Image not found")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            resp.status = HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            resp.writer.write("""{"error": "${e.message}"}""")
        }
    }
}
