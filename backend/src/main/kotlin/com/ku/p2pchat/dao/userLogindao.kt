package org.example.com.ku.p2pchat.com.ku.p2pchat.dao
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user


interface UserLogindao {
    fun login(number:String,password: String): user?
    fun findUserById(id:Int):user?
    fun updateUserPublicKey(user: user):Boolean
}