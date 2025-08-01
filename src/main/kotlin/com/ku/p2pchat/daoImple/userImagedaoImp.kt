package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import com.ku.p2pchat.database.DatabaseConnection
import org.example.com.ku.p2pchat.com.ku.p2pchat.dao.userImagedao
import org.example.com.ku.p2pchat.com.ku.p2pchat.model.userImage
import java.sql.Connection

class userImagedaoImp: userImagedao {
    val conn: Connection = DatabaseConnection.getConnection() as Connection

    override fun insertImage(image: userImage): Boolean {
 val sql="""INSERT INTO profile_image(userId,image_data) VALUES (?,?)""".trimIndent()
        val ps = conn.prepareStatement(sql)
        ps.setInt(1,image.userId)
        ps.setBytes(2,image.imageData)
       return ps.executeUpdate()>0
    }

    override fun updateImage(image: userImage): Boolean {
        val sql  ="""Update profile_image SET image_data=? where userId=?""".trimIndent()
        val ps =conn.prepareStatement(sql)
        ps.setBytes(1,image.imageData)
        ps.setInt(2,image.userId)
        return ps.executeUpdate()>0
    }

    override fun getImageByUserId(userId: Int): userImage? {
        val sql="""SELECT * from profile_image WHERE userId=?"""
        val ps =conn.prepareStatement(sql)
        ps.setInt(1,userId)
           val rs=ps.executeQuery()
           return if (rs.next()){
               userImage(
                   id=rs.getInt("id"),
                   userId=rs.getInt("userId"),
                   imageData = rs.getBytes("image_data")
               )

           }else null
    }
}