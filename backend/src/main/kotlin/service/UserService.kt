package org.example.com.ku.p2pchat.service

import org.example.com.ku.p2pchat.database.Users
import org.example.com.ku.p2pchat.model.*
import org.jetbrains.exposed.sql.*
import org.jetbrains.exposed.sql.transactions.transaction
import org.mindrot.jbcrypt.BCrypt

class UserService {
    
    fun registerUser(userRegister: userRegister): user? {
        return transaction {
            if (userRegister.Password != userRegister.RePassword) {
                throw Exception("Passwords do not match")
            }
            
            val existingUser = Users.select { Users.email eq userRegister.email }.firstOrNull()
            if (existingUser != null) {
                throw Exception("User already exists")
            }
            
            val hashedPassword = BCrypt.hashpw(userRegister.Password, BCrypt.gensalt())
            
            val userId = Users.insert {
                it[firstName] = userRegister.FirstName
                it[lastName] = userRegister.LastName
                it[phoneNo] = userRegister.PhoneNo
                it[email] = userRegister.email
                it[hashPassword] = hashedPassword
            } get Users.id
            
            user(
                id = userId,
                FirstName = userRegister.FirstName,
                LastName = userRegister.LastName,
                PhoneNo = userRegister.PhoneNo,
                email = userRegister.email,
                hashPassword = hashedPassword,
                publicKeyPem = null
            )
        }
    }
    
    fun loginUser(userLogin: userLogin): user? {
        return transaction {
            val row = Users.select { 
                (Users.email eq userLogin.number) or (Users.phoneNo eq userLogin.number) 
            }.firstOrNull()
            
            if (row != null && BCrypt.checkpw(userLogin.password, row[Users.hashPassword])) {
                user(
                    id = row[Users.id],
                    FirstName = row[Users.firstName],
                    LastName = row[Users.lastName],
                    PhoneNo = row[Users.phoneNo],
                    email = row[Users.email],
                    hashPassword = row[Users.hashPassword],
                    publicKeyPem = row[Users.publicKeyPem]
                )
            } else null
        }
    }
    
    fun getUserById(id: Int): user? {
        return transaction {
            val row = Users.select { Users.id eq id }.firstOrNull()
            row?.let {
                user(
                    id = it[Users.id],
                    FirstName = it[Users.firstName],
                    LastName = it[Users.lastName],
                    PhoneNo = it[Users.phoneNo],
                    email = it[Users.email],
                    hashPassword = it[Users.hashPassword],
                    publicKeyPem = it[Users.publicKeyPem]
                )
            }
        }
    }
}