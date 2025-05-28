package org.example.com.ku.p2pchat.dao

import org.example.com.ku.p2pchat.model.userRegister


interface registerDao {
    fun registerUser(user: userRegister): Boolean
}
