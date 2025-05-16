package org.example.com.ku.p2pchat.model

open class userRegister {
     var id: Int=0
    private var firstName: String=""
    private var lastName: String=""
    private var number:String=""
    private var email:String=""
    private var password:String=""
    private var rePassword: String=""

//    fun getId(): Int = id
//    fun setId(id: Int) {
//        this.id = id
//    }

    fun getFirstName(): String = firstName
    fun setFirstName(firstName: String) {
        this.firstName = firstName
    }

    fun getLastName(): String = lastName
    fun setLastName(lastName: String) {
        this.lastName = lastName
    }

    fun getNumber(): String = number
    fun setNumber(number: String) {
        this.number = number
    }

    fun getEmail(): String = email
    fun setEmail(email: String) {
        this.email = email
    }

    fun getPassword(): String = password
    fun setPassword(password: String) {
        this.password = password
    }

    fun getRepassword(): String = rePassword
    fun setRepassword(repassword: String) {
        this.rePassword = rePassword
    }
}