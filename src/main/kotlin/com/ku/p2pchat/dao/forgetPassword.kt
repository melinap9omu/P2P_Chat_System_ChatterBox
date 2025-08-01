package org.example.com.ku.p2pchat.com.ku.p2pchat.dao

interface forgetPassword {
    fun isNumberExist(number:String):Boolean
//    fun setResetCode(number:String,code:)
   fun updateResetCode(number:String,code:String,expiry:String):Boolean
    fun varifyCode(number: String,code: String):Boolean
    fun updatePassword(number: String,newPassword:String):Boolean
    fun clearResetcode(number:String): Boolean
}