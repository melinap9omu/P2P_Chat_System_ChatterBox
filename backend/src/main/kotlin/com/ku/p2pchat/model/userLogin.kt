package org.example.com.ku.p2pchat.com.ku.p2pchat.model

// Changed to a data class for conciseness and efficiency.
// Properties are now public 'val' or 'var' directly in the constructor.
data class userLogin(
    val number: String, // 'val' for immutable, or 'var' if you need to reassign
    val password: String // 'val' for immutable, or 'var' if you need to reassign
)
// No need for explicit getNumber(), setNumber(), etc. The compiler generates them.