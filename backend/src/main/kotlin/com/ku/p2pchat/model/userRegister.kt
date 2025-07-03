package org.example.com.ku.p2pchat.model

import kotlinx.serialization.Serializable

@Serializable
data class userRegister(
    val id: Int,
    val FirstName: String,
    val LastName: String,
    val PhoneNo: String,
    val email: String,
    val Password: String,
    val RePassword: String
)