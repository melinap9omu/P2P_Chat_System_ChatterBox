// user.kt - Updated model with profile image support
package org.example.com.ku.p2pchat.com.ku.p2pchat.model

data class user(
    var id: Int,
    val firstName: String,
    val lastName: String,
    val phoneNo: String,
    val email: String,
    val hashPassword: String?,
    val publicKeyPem: String?,
    val profileImagePath: String? = null, // New field for profile image
    val profileBackgroundColor: String? = null // New field for background color when using initials
)