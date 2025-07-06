package org.example.com.ku.p2pchat.model

import com.google.gson.annotations.SerializedName

open class userRegister {
    @SerializedName("first_name")
    var firstname: String = ""
    @SerializedName("last_name")
    var lastname: String = ""
    var number: String = ""
    var email: String = ""
    var password: String = ""
     var rePassword: String = ""
    @SerializedName("public_key_pem")
    var publicKeyPem: String = ""
}