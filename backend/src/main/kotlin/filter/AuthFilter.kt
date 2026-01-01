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

@WebFilter(urlPatterns = ["/public-key", "/users", "/signal", "/users/online"])
class AuthFilter : Filter {

    override fun init(filterConfig: FilterConfig?) {
        println("AuthFilter initialized.")
    }

    @Throws(IOException::class, ServletException::class)
    override fun doFilter(request: ServletRequest, response: ServletResponse, chain: FilterChain) {
        val httpRequest = request as HttpServletRequest
        val httpResponse = response as HttpServletResponse

        // Handle OPTIONS requests (preflight) - let them pass through
        if (httpRequest.method == "OPTIONS") {
            chain.doFilter(request, response)
            return
        }

        val path = httpRequest.requestURI
        println("DEBUG: AuthFilter checking path: $path")

        // Paths that do NOT require authentication
        if (path == "/login" || path == "/register" || path == "/websocket" || path== "/favicon.ico") {
            println("DEBUG: Path $path is public, allowing access")
            chain.doFilter(request, response)
            return
        }

        // Debug session information
        val session = httpRequest.getSession(false) // Don't create new session
        println("DEBUG: Session exists: ${session != null}")
        if (session != null) {
            println("DEBUG: Session ID: ${session.id}")
            println("DEBUG: Session is new: ${session.isNew}")
            println("DEBUG: Session attributes: ${session.attributeNames.toList()}")
        }

        val userId = session?.getAttribute("userId") as? Int
        println("DEBUG: UserId from session: $userId")

        if (userId == null) {
            println("DEBUG: No userId in session, returning 401 for path: $path")
            httpResponse.status = HttpServletResponse.SC_UNAUTHORIZED
            httpResponse.contentType = "application/json"
            httpResponse.writer.write("""{"success": false, "message": "Unauthorized: Please log in."}""")
            return
        }

        println("DEBUG: User $userId authenticated, proceeding with request to $path")
        chain.doFilter(request, response)
    }

    override fun destroy() {
        println("AuthFilter destroyed.")
    }
}