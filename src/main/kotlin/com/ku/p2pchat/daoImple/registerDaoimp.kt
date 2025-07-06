package org.example.com.ku.p2pchat.daoImple

import at.favre.lib.crypto.bcrypt.BCrypt
import com.ku.p2pchat.database.DatabaseConnection
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.com.ku.p2pchat.model.userRegister
import java.sql.Connection
import java.sql.DriverManager
import java.sql.SQLException

class registerDaoimp {
    val conn: Connection = DatabaseConnection.getConnection() as Connection

    fun registerUser(user: userRegister): Boolean {


        val sql = """
        INSERT INTO register (first_name,last_name,number,email,password,public_key_pem)
        VALUES (?,?,?,?,?,?)
    """.trimIndent()

        return try {
            val ps = conn.prepareStatement(sql)
            ps.setString(1, user.firstname)
            ps.setString(2, user.lastname)
            ps.setString(3, user.number)
            ps.setString(4, user.email)
            ps.setString(5, user.password)
            ps.setString(6, user.publicKeyPem)
            ps.executeUpdate() > 0

        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
