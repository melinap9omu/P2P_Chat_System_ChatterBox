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

    val jettyVersion = "11.0.24"

    // ✅ Jetty Server & Servlet
    implementation("org.eclipse.jetty:jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty:jetty-servlet:$jettyVersion") {
        exclude(group = "javax.servlet") // Just to prevent old servlet conflicts
    }
    implementation("org.eclipse.jetty:jetty-servlets:$jettyVersion")

    // ✅ Jetty WebSocket (optional if you use WebSocket)
    implementation("org.eclipse.jetty.websocket:websocket-jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-client:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-servlet:$jettyVersion")

    implementation("com.twilio.sdk:twilio:8.31.1")
    // ✅ Jakarta Servlet 5 — required for Jetty 11
    implementation("jakarta.servlet:jakarta.servlet-api:5.0.0")

    // ✅ Security
    implementation("at.favre.lib:bcrypt:0.9.0")

    // ✅ JSON
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("com.google.code.gson:gson:2.10.1")

    // ✅ Database drivers
    implementation("mysql:mysql-connector-java:8.0.33")
    implementation("com.zaxxer:HikariCP:5.0.1")
    implementation("org.xerial:sqlite-jdbc:3.45.1.0")
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
