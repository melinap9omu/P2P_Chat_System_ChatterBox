package org.example.com.ku.p2pchat.com.ku.p2pchat.database

import java.sql.Connection
import java.sql.SQLException

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
                    rePassword VARCHAR(100) NOT NULL,
                    reset_code VARCHAR(10),
                    reset_code_expiry DATETIME
                );
            """.trimIndent()

            connection.createStatement().use { statement ->
                // Create the register table if not exists
                statement.execute(createTable)
                println("✅ 'register' table initialized or already exists.")

                // Try adding the public_key_pem column if it doesn't exist
                try {
                    statement.execute("ALTER TABLE register ADD COLUMN public_key_pem TEXT;")
                    println("✅ 'public_key_pem' column added to 'register' table.")
                } catch (e: SQLException) {
                    // Ignore error if column already exists
                    println("ℹ️ 'public_key_pem' column probably already exists: ${e.message}")
                }

                val createProfileImageTable = """
                    CREATE TABLE IF NOT EXISTS profile_image (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        userId INT NOT NULL UNIQUE,
                        image_data LONGBLOB NOT NULL,
                        FOREIGN KEY (userId) REFERENCES register(id) ON DELETE CASCADE
                    );
                """.trimIndent()

                statement.execute(createProfileImageTable)
                println("✅ 'profile_image' table initialized or already exists.")


                // Create other tables
                val createFilesTable = """
                    CREATE TABLE IF NOT EXISTS files (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        sender_id INT NOT NULL,
                        receiver_id INT NOT NULL,
                        original_file_name VARCHAR(255) NOT NULL,
                        stored_file_path VARCHAR(255) NOT NULL,
                        mime_type VARCHAR(100),
                        file_size BIGINT,
                        upload_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        status VARCHAR(50) DEFAULT 'uploaded',
                        FOREIGN KEY (sender_id) REFERENCES register(id),
                        FOREIGN KEY (receiver_id) REFERENCES register(id)
                    );
                """.trimIndent()

                val createChatMessagesTable = """
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        sender_id INT NOT NULL,
                        receiver_id INT NOT NULL,
                        message_type VARCHAR(50) NOT NULL,
                        content TEXT,
                        file_id INT,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        status VARCHAR(50) DEFAULT 'sent',
                        FOREIGN KEY (sender_id) REFERENCES register(id),
                        FOREIGN KEY (receiver_id) REFERENCES register(id),
                        FOREIGN KEY (file_id) REFERENCES files(id)
                    );
                """.trimIndent()

                statement.execute(createFilesTable)
                println("✅ 'files' table initialized or already exists.")

                statement.execute(createChatMessagesTable)
                println("✅ 'chat_messages' table initialized or already exists.")
            }

        } catch (e: SQLException) {
            System.err.println("❌ SQL Error during database initialization: ${e.message}")
            e.printStackTrace()
        } catch (e: Exception) {
            System.err.println("❌ Unexpected error during database initialization: ${e.message}")
            e.printStackTrace()
        }
    }
}
