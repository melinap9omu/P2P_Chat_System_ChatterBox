package org.example.com.ku.p2pchat.com.ku.p2pchat.model

data class message(val senderId: String, val recipientId: String , val content:String, val type:String="chat" )