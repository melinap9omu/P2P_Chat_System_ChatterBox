package org.example.com.ku.p2pchat.com.ku.p2pchat.dao

import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user
import org.example.p2pchat.model.userLogin

interface userLogindao {
    fun login(number:String,password: String): userLogin?
    fun findUserById(number:String): userLogin?
//    fun updateUserPublicKey(user: userLogin):Boolean
//    fun getAllUsers(): List<userLogin>
}