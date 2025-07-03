package org.example.com.ku.p2pchat.com.ku.p2pchat.model

import kotlinx.serialization.Serializable

@Serializable
data class SignalingMessage(
    val type: String,
    val payload: String? = null,
    val targetUserId: Int? = null,
    val senderUserId: Int? = null
)