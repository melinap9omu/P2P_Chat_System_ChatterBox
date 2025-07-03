package org.example.com.ku.p2pchat.com.ku.p2pchat.model

import kotlinx.serialization.Serializable

@Serializable
data class user(
    val id: Int,
    val FirstName: String,
    val LastName: String,
    val PhoneNo: String,
    val email: String,
    val hashPassword: String,
    val publicKeyPem: String? = null