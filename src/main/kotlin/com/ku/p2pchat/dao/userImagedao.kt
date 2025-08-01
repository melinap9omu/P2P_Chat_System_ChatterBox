package org.example.com.ku.p2pchat.com.ku.p2pchat.dao

import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userImage

interface userImagedao {
    fun insertImage(image: userImage): Boolean
    fun updateImage(image: userImage): Boolean
    fun getImageByUserId(userId: Int): userImage?


}