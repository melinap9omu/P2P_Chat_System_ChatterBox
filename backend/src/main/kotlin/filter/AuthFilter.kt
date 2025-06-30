package org.example.p2pchat.filter


import jakarta.servlet.Filter
import jakarta.servlet.FilterChain
import jakarta.servlet.FilterConfig
import jakarta.servlet.ServletException
import jakarta.servlet.ServletRequest
import jakarta.servlet.ServletResponse
import jakarta.servlet.annotation.WebFilter
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import java.io.IOException

@WebFilter(urlPatterns = ["/public-key", "/users", "/signal"]) // Apply to protected paths
class AuthFilter : Filter {

    override fun init(filterConfig: FilterConfig?) {
        println("AuthFilter initialized.")
    }

    @Throws(IOException::class, ServletException::class)
    override fun doFilter(request: ServletRequest, response: ServletResponse, chain: FilterChain) {
        val httpRequest = request as HttpServletRequest
        val httpResponse = response as HttpServletResponse

        val path = httpRequest.requestURI

        // Paths that do NOT require authentication
        if (path == "/login" || path == "/register") {
            chain.doFilter(request, response) // Allow access
            return
        }

        // For other paths, check if user is logged in
        val session = httpRequest.session
        val userId = session.getAttribute("userId") as? Int

        if (userId == null) {
            httpResponse.status = HttpServletResponse.SC_UNAUTHORIZED // 401 Unauthorized
            httpResponse.contentType = "application/json"
            httpResponse.writer.write("""{"success": false, "message": "Unauthorized: Please log in."}""")
            println("Unauthorized access attempt to $path")
            return
        }

        // If authenticated, proceed with the request
        chain.doFilter(request, response)
    }

    override fun destroy() {
        println("AuthFilter destroyed.")
    }
}