package org.example.com.ku.p2pchat.com.ku.p2pchat.model

import kotlinx.serialization.Serializable

@Serializable
data class SignalingMessage(
    val type: String, // e.g., "offer", "answer", "candidate", "user_online", "user_offline", "online_users_list", "chat_message", "error"
    val payload: String? = null, // SDP or ICE data for WebRTC negotiation
    val senderUserId: Int? = null,
    val targetUserId: Int? = null,
    val senderUsername: String? = null, // Added for presence updates and general chat messages
    val onlineUsers: List<Map<String, Any>>? = null, // For "online_users_list" message type
    val message: String? = null // General purpose message, e.g., for simple notifications or error details
)