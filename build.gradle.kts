import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    kotlin("jvm") version "1.9.10"
    kotlin("plugin.serialization") version "1.9.10"

}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    google()
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
    implementation(kotlin("stdlib"))

    // Servlet API (Only one version needed — Jetty 11+ uses Jakarta 6.0.0)
    implementation("jakarta.servlet:jakarta.servlet-api:6.0.0")

    // Jetty WebSocket dependencies
    val jettyVersion = "11.0.24"
    implementation("org.eclipse.jetty:jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty:jetty-servlet:$jettyVersion")
    implementation("org.eclipse.jetty:jetty-servlets:${jettyVersion}")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-client:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-servlet:$jettyVersion")
    // Security
    implementation("at.favre.lib:bcrypt:0.9.0")

    // JSON (choose one: either Gson or kotlinx.serialization — both are okay too)
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("jakarta.servlet:jakarta.servlet-api:5.0.0")
    // MySQL connector
    implementation("mysql:mysql-connector-java:8.0.33")

    implementation("com.zaxxer:HikariCP:5.0.1") // Or your database connection pool
    implementation("org.xerial:sqlite-jdbc:3.45.1.0") // Or your specific JDBC driver


}

tasks.test {
    useJUnitPlatform()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "17"
}
