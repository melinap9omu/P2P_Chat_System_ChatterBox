import java.sql.Connection
import java.sql.DriverManager

fun main() {
    val jdbcUrl = "jdbc:mysql://localhost:3306/p2p_chat"
    val username = "root"
    val password = "suniti@123"

    try {
        val connection: Connection = DriverManager.getConnection(jdbcUrl, username, password)
        println("✅ Connected to the database!")

        // Attempt to create the table
        try {
            val createTable = """
                CREATE TABLE IF NOT EXISTS register (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    first_name VARCHAR(50) NOT NULL,
                    last_name VARCHAR(50) NOT NULL,
                    number VARCHAR(10) NOT NULL,
                    email VARCHAR(50) NOT NULL UNIQUE,
                    password_hash VARCHAR(255) NOT NULL
                    
                );
            """.trimIndent()

            val statement = connection.createStatement()
            statement.execute(createTable)
            println("✅ 'register' table created or already exists.")
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Failed to create 'register' table.")
        }

        // Confirm active database
        try {
            val statement1 = connection.createStatement()
            val resultSet = statement1.executeQuery("SELECT DATABASE();")
            while (resultSet.next()) {
                println("Current Database: ${resultSet.getString(1)}")
            }
        } catch (e: Exception) {
            e.printStackTrace()
            println("❌ Failed to retrieve current database.")
        }

        connection.close()
    } catch (e: Exception) {
        e.printStackTrace()
        println("❌ Failed to connect to the database.")
    }
}
