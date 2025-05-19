package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.userLogindao
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userLogin
import java.sql.DriverManager

class userLogindaoImp: userLogindao {
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val dbPassword = "suniti@123"
    override fun login(number: String, password: String): Boolean {
        val sql = "SELECT * FROM register WHERE number = ? AND password = ?"

        try {
            DriverManager.getConnection(jdbcUrl, username, dbPassword).use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, number)
                    statement.setString(2, password)

                    val resultSet = statement.executeQuery()
                    return resultSet.next()  //if match found
                }
            }
        }
        catch (e: Exception){
            e.printStackTrace()
        }

        return false



    }


}