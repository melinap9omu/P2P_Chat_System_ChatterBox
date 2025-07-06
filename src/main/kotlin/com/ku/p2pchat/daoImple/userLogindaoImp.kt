package org.example.com.ku.p2pchat.daoImple


import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.userLogindao
import org.example.p2pchat.model.userLogin
import java.sql.Connection
import java.sql.DriverManager

class userLogindaoImp : userLogindao {

    val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    val username = "root"
    val dbPassword = "suniti@123"

    fun getConnection(): Connection {
        return DriverManager.getConnection(jdbcUrl, username, dbPassword)
    }

    override fun login(number: String, password: String): userLogin? {
        val sql = "SELECT * FROM register WHERE number = ? AND password = ?"

        try {
            getConnection().use { connection ->  // use helper function
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, number)
                    statement.setString(2, password)

                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) {
                        val user = userLogin()
                        user.number = resultSet.getString("number")
                        user.password = resultSet.getString("password")
                        user.firstname = resultSet.getString("first_name") ?: ""  // Add this
                        user.lastname = resultSet.getString("last_name") ?: ""    // And this
                        return user
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return null
    }

    override fun findUserById(number: String): userLogin? {
        val sql = "SELECT * FROM register WHERE number = ?"

        try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, number)

                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) {
                        val user = userLogin()
                        user.number = resultSet.getString("number")
                        user.password = resultSet.getString("password")
                        user.firstname = resultSet.getString("first_name") ?: ""
                        user.lastname = resultSet.getString("last_name") ?: ""
                        return user
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return null
    }
}


//
//    override fun findUserById(id: Int): userLogin? {
//        val sql = "SELECT id, first_name, last_name, number, email, password, public_key_pem FROM register WHERE id = ?"
//
//        return try {
//            getConnection().use { conn ->
//                conn.prepareStatement(sql).use { ps ->
//                    ps.setInt(1, id)
//                    val rs = ps.executeQuery()
//                    if (rs.next()) {
//                        return userLogin(
//                            firstName = rs.getString("first_name"),
//                            lastName = rs.getString("last_name"),
//                            number = rs.getString("number"),
//                            email = rs.getString("email"),
//                            password = rs.getString("password"),
//                            publicKeyPem = rs.getString("public_key_pem")
//                        )
//                    }
//                }
//            }
//            null
//        } catch (e: Exception) {
//            println("❌ Error finding user by ID: ${e.message}")
//            e.printStackTrace()
//            null
//        }
//    }
//
//
//
//    override fun updateUserPublicKey(user: userLogin): Boolean {
//        val sql = "UPDATE register SET public_key_pem = ? WHERE id = ?"
//
//        return try {
//            getConnection().use { conn ->
//                conn.prepareStatement(sql).use { ps ->
//                    ps.setString(1, user.publicKeyPem)
//                    ps.setInt(2, user.id)
//                    ps.executeUpdate() > 0
//                }
//            }
//        } catch (e: Exception) {
//            println("❌ Error updating public key for user ${user.id}: ${e.message}")
//            e.printStackTrace()
//            false
//        }
//    }
//
//    override fun getAllUsers(): List<userLogin> {
//        val users = mutableListOf<user>()
//        val sql = "SELECT id, first_name, last_name, number, email, password, public_key_pem FROM register"
//
//        try {
//            getConnection().use { conn ->
//                conn.prepareStatement(sql).use { ps ->
//                    val rs = ps.executeQuery()
//                    while (rs.next()) {
//                        users.add(
//                            user(
//                                id = rs.getInt("id"),
//                                firstName = rs.getString("first_name"),
//                                lastName = rs.getString("last_name"),
//                                number = rs.getString("number"),
//                                email = rs.getString("email"),
//                                password = rs.getString("password"),
//                                publicKeyPem = rs.getString("public_key_pem")
//                            )
//                        )
//                    }
//                }
//            }
//        } catch (e: Exception) {
//            println("❌ Error fetching all users: ${e.message}")
//            e.printStackTrace()
//        }
//
//        return userLogin
//    }
//}
