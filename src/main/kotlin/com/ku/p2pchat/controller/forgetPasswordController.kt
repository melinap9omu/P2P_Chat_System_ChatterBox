package org.example.com.ku.p2pchat.com.ku.p2pchat.controller

import jakarta.servlet.annotation.WebServlet
import jakarta.servlet.http.HttpServlet
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple.forgetPassworddaoImp
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

@WebServlet("/forgetPassword")
class forgetPasswordController : HttpServlet() {
    private val dao = forgetPassworddaoImp()

    override fun doPost(req: HttpServletRequest, resp: HttpServletResponse) {
        resp.contentType = "application/json" // ✅ Important for Flutter to parse JSON
        val writer = resp.writer

        val action = req.getParameter("action")
        val number = req.getParameter("number") ?: return

        when (action) {
            "send-code" -> {
                if (dao.isNumberExist(number)) {
                    val code = (1000..9999).random().toString()
                    val expiry = LocalDateTime.now()
                        .plusMinutes(5)
                        .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")) // ✅ Correct pattern

                    dao.updateResetCode(number, code, expiry)

                    // Simulate SMS sending
                    println("SMS sent to $number with code: $code")

                    // ✅ Send JSON response
                    writer.write(
                        """
                        {
                          "success": true,
                          "message": "Reset code generated",
                          "code": "$code"
                        }
                        """.trimIndent()
                    )
                } else {
                    writer.write(
                        """
                        {
                          "success": false,
                          "message": "Number not found"
                        }
                        """.trimIndent()
                    )
                }
            }

            "resetPassword" -> {
                val code = req.getParameter("code") ?: return
                val newPassword = req.getParameter("newPassword") ?: return

                if (dao.varifyCode(number, code)) {
                    dao.updatePassword(number, newPassword)
                    dao.clearResetcode(number)

                    writer.write(
                        """
                        {
                          "success": true,
                          "message": "Password updated successfully"
                        }
                        """.trimIndent()
                    )
                } else {
                    writer.write(
                        """
                        {
                          "success": false,
                          "message": "Invalid or expired code"
                        }
                        """.trimIndent()
                    )
                }
            }

            else -> {
                writer.write(
                    """
                    {
                      "success": false,
                      "message": "Invalid action"
                    }
                    """.trimIndent()
                )
            }
        }
    }
}
