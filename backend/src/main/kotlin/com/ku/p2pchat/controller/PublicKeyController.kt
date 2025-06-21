package org.example.com.ku.p2pchat.com.ku.p2pchat.controller
import com.google.gson.Gson
import com.google.gson.JsonParser
import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.userLogindaoImp // Use your existing DAO
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user

import java.io.IOException

@WebServlet("/public-key")
class PublicKeyController: HttpServlet() {
    private val gson = Gson()

    private lateinit var userDao: userLogindaoImp
    override fun init(){
        super.init()
        userDao= userLogindaoImp()

    }

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse){
        resp.contentType="application/json"
        val out = resp.writer
        val userId = req.session.getAttribute("userId") as? Int

        if (userId==null){
            resp.status = HttpServletResponse.SC_UNAUTHORIZED
            out.write(gson.toJson(mapOf("success" to false,
                                                   "message" to "Unauthorized. Please Log in.")))
            return
        }

            try {
                val publicKeyPem = req.reader.readText()

                if (publicKeyPem.isBlank()) {
                    resp.status = HttpServletResponse.SC_BAD_REQUEST
                    out.write(
                        gson.toJson(
                            mapOf(
                                "success" to false,
                                "message" to "Public Key cannot be empty"
                            )
                        )
                    )
                    return
                }
                val currentUser = userDao.findUserById(userId) as? user
                if (currentUser == null) {
                    resp.status = HttpServletResponse.SC_NOT_FOUND
                    out.write(
                        gson.toJson(
                            mapOf(
                                "success" to false,
                                "message" to "Authenticated user data not found"
                            )
                        )
                    )
                    return
                }
                val updatedUser = currentUser.copy(publicKeyPem = publicKeyPem)

                val success = userDao.updateUserPublicKey(updatedUser)

                if (success) {
                    resp.status = HttpServletResponse.SC_OK
                    out.write(gson.toJson(mapOf("success" to true, "message" to "Public Key uploaded sucessfully")))
                }
                else{
                    resp.status= HttpServletResponse.SC_INTERNAL_SERVER_ERROR
                    out.write(gson.toJson(mapOf("success" to false, "message" to "Failed to upload public key to database")))

                }
            }
            catch (e: Exception){
                System.err.println("Error uploading public key for user $userId")
                e.printStackTrace()
                resp.status = HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "Server error or invaled public key format: ${e.message}")))


            }
            finally {
                out.close()
            }


    }

    override fun doGet(req: HttpServletRequest, resp: HttpServletResponse){
        resp.contentType= "application/json"
        val out= resp.writer
        val userId = req.session.getAttribute("userId") as? Int

        val targetUserIdParam = req.getParameter("targetUserId") as? Int

        if (userId==null){
            resp.status = HttpServletResponse.SC_UNAUTHORIZED
            out.write(gson.toJson(mapOf("success" to false, "message" to "Unauthorized,Please Log in")))
            return
        }

        if (targetUserIdParam==null){
            resp.status = HttpServletResponse.SC_BAD_REQUEST
            out.write(gson.toJson(mapOf("success" to false, "message" to "Missing or invalid 'targetUserId' parameter")))
            return
        }

        try{

        }
        catch (e:Exception){

        }
        finally{

        }


    }
    




}