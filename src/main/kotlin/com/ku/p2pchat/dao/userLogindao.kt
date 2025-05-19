package org.example.com.ku.p2pchat.com.ku.p2pchat.dao

import org.eclipse.jetty.util.security.Password
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userLogin

interface userLogindao {
    fun login(number:String,password: String): Boolean
}