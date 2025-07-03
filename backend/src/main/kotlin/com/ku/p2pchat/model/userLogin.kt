package org.example.com.ku.p2pchat.com.ku.p2pchat.model

import kotlinx.serialization.Serializable

@Serializable
data class userLogin(
    val number: String,
    val password: String
)