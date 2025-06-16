package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.UserLogindao
import at.favre.lib.crypto.bcrypt.BCrypt
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.sql.DriverManager

class userLogindaoImp: UserLogindao {
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val dbPassword = "suniti@123"
    override fun login(number: String, password: String): user?{
        val sql = "SELECT id, first_name, last_name, number, email, password_hash FROM register WHERE number = ?"

        try {
            DriverManager.getConnection(jdbcUrl, username, dbPassword).use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, number)
                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) { //if match found
                        val storedHashPassword = resultSet.getString("password_hash")

                        if (BCrypt.verifyer().verify(password.toCharArray(), storedHashPassword.toCharArray()).verified) {
                            return user(
                                id = resultSet.getInt("id"),
                                FirstName = resultSet.getString("first_name"),
                                LastName = resultSet.getString("last_name"),
                                PhoneNo = resultSet.getString("number"),
                                email = resultSet.getString("email"),
                                hashPassword = resultSet.getString("password_hash")
                            )

                        }
                    }
                }
            }
        }
        catch (e: Exception){ // Catches any database connection or query execution errors
                e.printStackTrace() // Prints the error stack trace to the console for debugging
            }

        return null



    }


}