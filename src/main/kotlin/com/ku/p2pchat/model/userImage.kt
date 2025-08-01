package org.example.com.ku.p2pchat.com.ku.p2pchat.model

data class userImage (
    val id: Int = 0,               // Auto-incremented ID (optional)
    val userId: Int,               // Foreign key to register(id)
    val imageData: ByteArray
)