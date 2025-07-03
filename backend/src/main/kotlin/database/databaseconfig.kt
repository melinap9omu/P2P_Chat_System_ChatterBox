package org.example.com.ku.p2pchat.database

import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction

object Users : Table() {
    val id = integer("id").autoIncrement()
    val firstName = varchar("first_name", 50)
    val lastName = varchar("last_name", 50)
    val phoneNo = varchar("phone_no", 20)
    val email = varchar("email", 100)
    val hashPassword = varchar("hash_password", 255)
    val publicKeyPem = text("public_key_pem").nullable()
    
    override val primaryKey = PrimaryKey(id)
}

object DatabaseConfig {
    fun init() {
        Database.connect("jdbc:h2:mem:test;DB_CLOSE_DELAY=-1", driver = "org.h2.Driver")
        transaction {
            SchemaUtils.create(Users)
        }
    }
}