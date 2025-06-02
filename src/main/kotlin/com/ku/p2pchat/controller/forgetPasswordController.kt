package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.forgetPassworddaoImp
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter


@WebServlet("/forgetPassword")
class forgetPasswordController: HttpServlet() {
     private val dao= forgetPassworddaoImp()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
     val action=req.getParameter("action")
        val number=req.getParameter("number")?:return
        val writen=resp.writer

        when(action){
            "send-code"->{
                if(dao.isNUmberExist(number)){
                    val code=(1000..9999).random().toString()
                    val expiry= LocalDateTime.now().plusMinutes(5).format(DateTimeFormatter.ofPattern("YYYY-MM-dd HH:mm:ss"))

                    dao.updateResetCode(number,code,expiry)

                    // TODO: Send SMS here
                    println("SMS sent to $number with code: $code") // Replace with SMS API

                    writen.write("Code sent")
                }
                else{
                    writen.write("Number not found")

                }
            }
            "resetPassword"->{
                val code=req.getParameter("code")?:return
                val newPassword=req.getParameter("newPassword")?:return

                if(dao.varifyCode(number,code)){
                    dao.updatePassword(number,newPassword)
                    dao.clearResetcode(number)
                    writen.write("password update sucessflly")
                }
                else{
                    writen.write("Invalid or expired code")
                }
            }
            else -> writen.write("Invalid action")
        }
    }
}