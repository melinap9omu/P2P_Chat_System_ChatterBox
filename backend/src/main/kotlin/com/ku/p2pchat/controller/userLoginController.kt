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
class userLoginController: HttpServlet(){
    val gson = Gson()
    val dao= userLogindaoImp()

    override fun doPost(req:HttpServletRequest, resp:HttpServletResponse){
        resp.contentType="application/json"
        val out = resp.writer

        try{
            val reader= req.reader
            val loginRequest = gson.fromJson(reader, userLogin::class.java)

            if (loginRequest.password.isNullOrBlank()|| loginRequest.number.isNullOrBlank()){
                resp.status=HttpServletResponse.SC_BAD_REQUEST
                out.write(gson.toJson(mapOf("success" to false, "message" to "Number and Password Required")))
                return

            }

            val authenticatedUser:user?= dao.login(loginRequest.number, loginRequest.password)

            val responseMap= if(authenticatedUser!=null){
                val  httpSession= req.getSession()
                httpSession.setAttribute("userId", authenticatedUser.id)
                httpSession.setAttribute("User", authenticatedUser)

                mapOf("success" to true,
                      "message" to "Login Successfully",
                      "userId"  to authenticatedUser.id,
                      "user"  to authenticatedUser)

            }
            else{
                mapOf("success" to false,
                    "message" to "Couldnot Login")

            }
            resp.status= HttpServletResponse.SC_OK
            out.write(gson.toJson(responseMap))
        }
        catch(e: Exception){
            resp.status= HttpServletResponse.SC_INTERNAL_SERVER_ERROR
            out.write(gson.toJson(mapOf("success" to false, "message" to "Error: ${e.message}")))
        }

        finally {
            out.flush()
            out.close()
        }


    }


}
