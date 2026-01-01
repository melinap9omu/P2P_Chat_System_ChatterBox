// userRegister.kt - Updated with profile image support
package org.example.com.ku.p2pchat.model

data class userRegister(
    var id: Int,
    val firstName: String,
    val lastName: String,
    val phoneNo: String,
    val email: String,
    val password: String,
    val rePassword: String,
    val profileImageBase64: String? = null // New field for base64 encoded image
)