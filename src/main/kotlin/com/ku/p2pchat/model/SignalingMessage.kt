package org.example.com.ku.p2pchat.com.ku.p2pchat.model

data class SignalingMessage(
    val type: String,
    val targetUserId: Int?,
    val payload: String,
    val senderUserId: Int? = null
)
