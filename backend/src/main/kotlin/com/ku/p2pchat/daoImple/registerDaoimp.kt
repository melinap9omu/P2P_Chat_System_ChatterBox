package org.example.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.dao.registerDao
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.sql.DriverManager

class registerDaoimp : registerDao {
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val password = "melina"

    override fun registerUser(user: user): Boolean {
        println("DEBUG: User object values received in registerDaoimp:")
        println(" userId: ${user.id}")
        println("  firstName: ${user.firstName}")
        println("  lastName: ${user.lastName}")
        println("  phoneNo: ${user.phoneNo}")
        println("  email: ${user.email}")
        println("  hashPassword (first 10 chars): ${user.hashPassword?.take(10)}")
        println("  publicKeyPem: ${user.publicKeyPem}")
        println("  profileImagePath: ${user.profileImagePath}")
        println("  profileBackgroundColor: ${user.profileBackgroundColor}")

        val sql = """
            INSERT INTO register (first_name, last_name, phone_no, email, password_hash, public_key_pem, profile_image_path, profile_background_color)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """.trimIndent()

        return try {
            DriverManager.getConnection(jdbcUrl, username, password).use { connection ->
                connection.prepareStatement(sql, java.sql.Statement.RETURN_GENERATED_KEYS).use { ps ->
                    ps.setString(1, user.firstName)
                    ps.setString(2, user.lastName)
                    ps.setString(3, user.phoneNo)
                    ps.setString(4, user.email)
                    ps.setString(5, user.hashPassword)
                    ps.setString(6, user.publicKeyPem)
                    ps.setString(7, user.profileImagePath)
                    ps.setString(8, user.profileBackgroundColor)

                    val rowsInserted = ps.executeUpdate()
                    if (rowsInserted > 0) {
                        val generatedKeys = ps.generatedKeys
                        if (generatedKeys.next()) {
                            user.id = generatedKeys.getInt(1)
                            println("DEBUG: Assigned generated user ID: ${user.id}")
                        }
                        true
                    } else {
                        false
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}