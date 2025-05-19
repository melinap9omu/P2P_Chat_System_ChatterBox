package org.example.com.ku.p2pchat.com.ku.p2pchat.model

open class userLogin {
    private var number:String=""
    private var password:String=""

    fun getNumber(): String = number
    fun setNumber(number: String) {
        this.number = number
    }

    fun getPassword(): String= password
    fun setPassword(password:String){
        this.password=password
    }
}