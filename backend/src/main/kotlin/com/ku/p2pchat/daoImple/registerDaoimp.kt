package org.example.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.dao.registerDao
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.sql.DriverManager

class registerDaoimp: registerDao{
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val password = "suniti@123"

  override  fun registerUser(user: user): Boolean {
        val sql = """
            INSERT INTO register (first_name, last_name, number, email, password_hash)
            VALUES (?, ?, ?, ?, ?)
        """.trimIndent()

        return try {
            DriverManager.getConnection(jdbcUrl, username, password).use { connection ->
                connection.prepareStatement(sql).use { ps ->
                    ps.setString(1, user.FirstName)
                    ps.setString(2, user.LastName)
                    ps.setString(3, user.PhoneNo)
                    ps.setString(4, user.email)
                    ps.setString(5, user.hashPassword)
                    ps.executeUpdate() > 0
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
