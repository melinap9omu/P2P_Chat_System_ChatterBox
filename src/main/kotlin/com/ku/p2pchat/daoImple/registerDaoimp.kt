package org.example.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.model.userRegister
import java.sql.DriverManager

class registerDaoimp: userRegister() {
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val password = "suniti@123"

    fun registerUser(user: userRegister): Boolean {
        val sql = """
            INSERT INTO register (first_name, last_name, number, email, password, re_password)
            VALUES (?, ?, ?, ?, ?, ?)
        """.trimIndent()

        return try {
            DriverManager.getConnection(jdbcUrl, username, password).use { connection ->
                connection.prepareStatement(sql).use { ps ->
                    ps.setString(1, user.getFirstName())
                    ps.setString(2, user.getLastName())
                    ps.setString(3, user.getNumber())
                    ps.setString(4, user.getEmail())
                    ps.setString(5, user.getPassword())
                    ps.setString(6, user.getRepassword())
                    ps.executeUpdate() > 0
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
