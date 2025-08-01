package org.example.com.ku.p2pchat.com.ku.p2pchat.daoImple

import com.ku.p2pchat.database.DatabaseConnection

import org.example.com.ku.p2pchat.com.ku.p2pchat.model.forgetPassword
import java.sql.Connection
import java.sql.DriverManager
import java.sql.ResultSet

class forgetPassworddaoImp: org.example.com.ku.p2pchat.com.ku.p2pchat.dao.forgetPassword {
    val conn: Connection= DatabaseConnection.getConnection() as Connection
    override fun isNumberExist(number: String): Boolean {
        val sql = "SELECT * FROM register WHERE number=?"
        val ps = conn.prepareStatement(sql)
        ps.setString(1, number)
        val rs: ResultSet = ps.executeQuery()
        return rs.next()
    }


    override fun updateResetCode(number: String, code: String, expiry: String): Boolean {

        val sql1="UPDATE register SET reset_code=?, reset_code_expiry=? WHERE number=?"
        val ps = conn.prepareStatement(sql1)
        ps.setString(1,code)
        ps.setString(2,expiry)
        ps.setString(3,number)
        return ps.executeUpdate()>0
     }

    override fun varifyCode(number: String, code: String): Boolean {

        val sql2="SELECT * FROM register WHERE number=? AND reset_code=?"
        val varifyCode=conn.prepareStatement(sql2)
        varifyCode.setString(1,number)
        varifyCode.setString(2,code)
        val rs=varifyCode.executeQuery()
        return rs.next()
    }

    override fun updatePassword(number: String, newPassword: String): Boolean {

        val sql3 = "UPDATE register SET password = ? WHERE number = ?"
        val updatePassword=conn.prepareStatement(sql3)
        updatePassword.setString(1,newPassword)
        updatePassword.setString(2,number)

        return updatePassword.executeUpdate()>0

    }

    override fun clearResetcode(number: String): Boolean {

        val sql4="UPDATE register SET reset_code=NULL,reset_code_expiry = NULL WHERE number = ? "
        val clear=conn.prepareStatement(sql4)
        clear.setString(1,number)
        return clear.executeUpdate()>0
    }


}