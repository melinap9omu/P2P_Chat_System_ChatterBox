// File: database/DatabaseConnection.kt
package com.ku.p2pchat.database

import java.sql.Connection
import java.sql.DriverManager

object DatabaseConnection {
    private const val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    private const val username = "root"
    private const val password = "suniti@123"

    fun getConnection(): Connection {
        return DriverManager.getConnection(jdbcUrl, username, password)
    }
}
