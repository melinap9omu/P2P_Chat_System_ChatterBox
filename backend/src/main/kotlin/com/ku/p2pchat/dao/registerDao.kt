package org.example.com.ku.p2pchat.dao

import org.example.com.ku.p2pchat.com.ku.p2pchat.model.user





interface registerDao {
    fun registerUser(user: user): Boolean
}
