package org.example.com.ku.p2pchat.com.ku.p2pchat.database

import java.sql.Connection


object databaseTable {
    fun initializeDatabase(connection: Connection) {
        try {
            val createTable = """
                CREATE TABLE IF NOT EXISTS register (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    first_name VARCHAR(50) NOT NULL,
                    last_name VARCHAR(50) NOT NULL,
                    number VARCHAR(10) NOT NULL,
                    email VARCHAR(50) NOT NULL UNIQUE,
                    password VARCHAR(100) NOT NULL,
                    re_password VARCHAR(100) NOT NULL,
                    reset_code VARCHAR(10),
                    reset_code_expiry DATETIME
                );
            """.trimIndent()

            val statement = connection.createStatement()
            statement.execute(createTable)
            println("✅ Table initialized or already exists.")

        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Failed to initialize database.")
        }
    }
}