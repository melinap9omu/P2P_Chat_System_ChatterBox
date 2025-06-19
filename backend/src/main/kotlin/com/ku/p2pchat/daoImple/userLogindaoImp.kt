package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.UserLogindao
import at.favre.lib.crypto.bcrypt.BCrypt
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.sql.DriverManager
import java.sql.Connection

class userLogindaoImp: UserLogindao {
    private val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private val username = "root"
    private val dbPassword = "suniti@123"

    private fun getConnection() : java.sql.Connection {
        return DriverManager.getConnection(jdbcUrl, username, dbPassword)

    }
    override fun login(number: String, password: String): user?{
        val sql = "SELECT id, first_name, last_name, number, email, password_hash FROM register WHERE number = ?"

        try {
            getConnection().use { connection ->
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
                                hashPassword = resultSet.getString("password_hash"),
                                publicKeyPem = resultSet.getString("public_key_pem")
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

    override fun findUserById(id: Int): user? {

        val sql = "SELECT id, first_name, last_name, number, email, password_hash, public_key_pem FROM register WHERE id = ?"
        return try{
            getConnection().use{ connection->
                connection.prepareStatement(sql).use{ps->
                    ps.setInt(1, id)
                    val rs = ps.executeQuery()
                    if(rs.next()){
                        user(
                            id = rs.getInt("id"),
                            FirstName = rs.getString("first_name"),
                            LastName = rs.getString("last_name"),
                            PhoneNo = rs.getString("number"),
                            email = rs.getString("email"),
                            hashPassword = rs.getString("password_hash"),
                            publicKeyPem = rs.getString("public_key_pem")

                        )
                    }
                    else{
                        null
                    }
                }
            }
        }
        catch(e: Exception){
            System.err.println("Error finding user bu Id $id: ${e.message}")
            e.printStackTrace()
            null
        }

    }

    override fun updateUserPublicKey(user: user): Boolean {
        val sql = "Update register SET public_key_pem = ? WHERE id = ?"
        return try{
            getConnection().use {connection ->
                connection.prepareStatement(sql).use { ps ->
                    ps.setString(1, user.publicKeyPem)
                    ps.setInt(2, user.id)
                    ps.executeUpdate() > 0
                }
            }
        }
        catch(e:Exception){
            System.err.println("Error updating public key for use ${user.id}: ${e.message}")
            e.printStackTrace()
            false
        }

    }



}