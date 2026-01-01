package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.UserLogindao
import at.favre.lib.crypto.bcrypt.BCrypt
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import java.sql.DriverManager
import java.sql.Connection
import org.example.com.ku.p2pchat.com.ku.p2pchat.database.DatabaseManager
import java.sql.Statement
import java.sql.ResultSet



class userLogindaoImp : UserLogindao {

    private fun getConnection(): Connection {
        return DatabaseManager.getConnection()
    }

    override fun login(email: String, password: String): user? {
        val sql = """
            SELECT id, first_name, last_name, phone_no, email, password_hash, public_key_pem
            FROM register
            WHERE email = ?
        """.trimIndent()

        try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, email)
                    println("DEBUG: Searching for email: $email")
                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) {
                        val storedHashPassword = resultSet.getString("password_hash")
                        val userId = resultSet.getInt("id")
                        val userFirstName = resultSet.getString("first_name")

                        println("✅ DEBUG: User found - ID: $userId, Name: $userFirstName")
                        println("🔑 DEBUG: Stored hash length: ${storedHashPassword?.length}")
                        println("🔑 DEBUG: Input password length: ${password.length}")

                        if (storedHashPassword.isNullOrEmpty()) {
                            println("❌ DEBUG: Stored password hash is null or empty!")
                            return null
                        }

                        val verificationResult = BCrypt.verifyer().verify(password.toCharArray(), storedHashPassword.toCharArray())
                        println("🔐 DEBUG: Password verification result: ${verificationResult.verified}")

                        if (verificationResult.verified) {
                            return user(
                                id = resultSet.getInt("id"),
                                firstName = resultSet.getString("first_name"),
                                lastName = resultSet.getString("last_name"),
                                phoneNo = resultSet.getString("phone_no"),
                                email = resultSet.getString("email"),
                                hashPassword = storedHashPassword,
                                publicKeyPem = resultSet.getString("public_key_pem")
                            )
                        } else{
                            println("DEBUG: Password verification failed")

                            try {
                                val testHash = BCrypt.withDefaults().hashToString(12, password.toCharArray())
                                println("🧪 DEBUG: Test hash of input password: $testHash")
                            } catch (e: Exception) {
                                println("DEBUG: Error creating test hash: ${e.message}")
                            }
                        }
                    }else{
                        println(" DEBUG: No user found with email: $email")

                    }

                }
            }
        } catch (e: Exception) {
            System.err.println(" Login failed: ${e.message}")
            e.printStackTrace()
        }

        return null
    }

    override fun findUserById(id: Int): user? {
        val sql = """
            SELECT id, first_name, last_name, phone_no, email, password_hash, public_key_pem
            FROM register
            WHERE id = ?
        """.trimIndent()

        return try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setInt(1, id)
                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) {
                        user(
                            id = resultSet.getInt("id"),
                            firstName = resultSet.getString("first_name"),
                            lastName = resultSet.getString("last_name"),
                            phoneNo = resultSet.getString("phone_no"),
                            email = resultSet.getString("email"),
                            hashPassword = resultSet.getString("password_hash"),
                            publicKeyPem = resultSet.getString("public_key_pem")
                        )
                    } else null
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error finding user by ID $id: ${e.message}")
            e.printStackTrace()
            null
        }
    }


    override fun updateUserPassword(userId: Int, newHashedPassword: String): Boolean {
        return try {
            val connection = DatabaseManager.getConnection()
            // Corrected SQL query to use 'register' table and 'password_hash' column
            val query = "UPDATE register SET password_hash = ? WHERE id = ?"

            connection.use { conn ->
                conn.prepareStatement(query).use { stmt ->
                    stmt.setString(1, newHashedPassword)
                    stmt.setInt(2, userId)

                    val rowsAffected = stmt.executeUpdate()
                    println("DEBUG: Password update - Rows affected: $rowsAffected for user ID: $userId")

                    rowsAffected > 0
                }
            }
        } catch (e: Exception) {
            System.err.println("Error updating user password: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    override fun updateUserPublicKey(user: user): Boolean {
        val sql = "UPDATE register SET public_key_pem = ? WHERE id = ?"

        return try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, user.publicKeyPem)
                    statement.setInt(2, user.id)

                    val rowsAffected = statement.executeUpdate()
                    println("✅ DEBUG: Rows affected when updating public key: $rowsAffected")
                    rowsAffected > 0
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error updating public key for user ${user.id}: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    override fun getAllUsers(): List<user> {
        val users = mutableListOf<user>()
        val sql = """
            SELECT id, first_name, last_name, phone_no, email, password_hash, public_key_pem
            FROM register
        """.trimIndent()

        try {
            getConnection().use { connection ->
                connection.createStatement().use { statement ->
                    statement.executeQuery(sql).use { resultSet ->
                        while (resultSet.next()) {
                            users.add(
                                user(
                                    id = resultSet.getInt("id"),
                                    firstName = resultSet.getString("first_name"),
                                    lastName = resultSet.getString("last_name"),
                                    phoneNo = resultSet.getString("phone_no"),
                                    email = resultSet.getString("email"),
                                    hashPassword = resultSet.getString("password_hash"),
                                    publicKeyPem = resultSet.getString("public_key_pem")
                                )
                            )
                        }
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error fetching all users: ${e.message}")
            e.printStackTrace()
        }

        return users
    }

    override fun getProfileImagePath(userId: Int): String? {
        val sql = "SELECT profile_image_path FROM register WHERE id = ?"
        try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setInt(1, userId)
                    val resultSet = statement.executeQuery()
                    if (resultSet.next()) {
                        return resultSet.getString("profile_image_path")
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error fetching profile image path for user $userId: ${e.message}")
            e.printStackTrace()
        }
        return null
    }

    override fun updateProfileImagePath(userId: Int, imagePath: String): Boolean {
        val sql = "UPDATE register SET profile_image_path = ? WHERE id = ?"
        return try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setString(1, imagePath)
                    statement.setInt(2, userId)
                    val rowsAffected = statement.executeUpdate()
                    rowsAffected > 0
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error updating profile image path for user $userId: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    override fun deleteProfileImagePath(userId: Int): Boolean {
        val sql = "UPDATE register SET profile_image_path = NULL WHERE id = ?"
        return try {
            getConnection().use { connection ->
                connection.prepareStatement(sql).use { statement ->
                    statement.setInt(1, userId)
                    val rowsAffected = statement.executeUpdate()
                    rowsAffected > 0
                }
            }
        } catch (e: Exception) {
            System.err.println("❌ Error deleting profile image path for user $userId: ${e.message}")
            e.printStackTrace()
            false
        }
    }
}
