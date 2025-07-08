package org.example.com.ku.p2pchat.com.ku.p2pchat.database



import java.sql.Connection
import java.sql.DriverManager
import java.sql.SQLException

object DatabaseManager {



    // --- Configuration for MySQL (Uncomment and set your details for persistent storage) ---
    private const val JDBC_URL = "jdbc:mysql://localhost:3306/p2p_chat" // Your MySQL URL
    private const val DB_USERNAME = "root" // Your MySQL username
    private const val DB_PASSWORD = "Krishtina12@" // Your MySQL password
    private const val DB_DRIVER = "com.mysql.cj.jdbc.Driver" // MySQL JDBC Driver

    init {
        try {
            Class.forName(DB_DRIVER) // Load the JDBC driver
            println("✅ JDBC Driver loaded: $DB_DRIVER")
        } catch (e: ClassNotFoundException) {
            System.err.println("❌ JDBC Driver not found: $DB_DRIVER. Make sure it's in your classpath.")
            e.printStackTrace()
        }
    }

    fun getConnection(): Connection {
        return DriverManager.getConnection(JDBC_URL, DB_USERNAME, DB_PASSWORD)
    }

    fun createTables() {
        var connection: Connection? = null
        try {
            connection = getConnection()
            val createTable = """
                CREATE TABLE IF NOT EXISTS register (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    first_name VARCHAR(50) NOT NULL,
                    last_name VARCHAR(50) NOT NULL,
                    phone_no VARCHAR(20) NOT NULL UNIQUE, -- Changed from 'number' to 'phone_no' for consistency with Exposed model
                    email VARCHAR(100) NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    public_key_pem TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """.trimIndent() // Using phone_no for consistency with Flutter User model

            val statement = connection.createStatement()
            statement.execute(createTable)
            println("✅ 'register' table created or already exists.")
        } catch (e: SQLException) {
            System.err.println("❌ Failed to create 'register' table: ${e.message}")
            e.printStackTrace()
        } finally {
            connection?.close()
        }
    }
}
