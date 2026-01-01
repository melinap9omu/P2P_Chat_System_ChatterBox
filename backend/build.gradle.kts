import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    kotlin("jvm") version "2.1.20"
    application
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

    // Servlet API – compileOnly because Jetty provides it at runtime
    compileOnly("jakarta.servlet:jakarta.servlet-api:6.0.0")

    implementation("com.google.code.gson:gson:2.10.1")
    implementation("mysql:mysql-connector-java:8.0.33")

    // Jetty & WebSocket
    val jettyVersion = "11.0.24"
    implementation("org.eclipse.jetty:jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty:jetty-servlet:$jettyVersion")
    implementation("org.eclipse.jetty:jetty-servlets:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-server:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-client:$jettyVersion")
    implementation("org.eclipse.jetty.websocket:websocket-servlet:$jettyVersion")

    implementation("at.favre.lib:bcrypt:0.9.0")
}

application {
    // <--- put your real package + file name here
    mainClass.set("org.example.com.ku.p2pchat.MainKt")
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {      // new DSL (no deprecation warning)
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
