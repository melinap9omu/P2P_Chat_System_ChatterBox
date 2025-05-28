import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    kotlin("jvm") version "2.1.20"
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
    providedCompile("jakarta.servlet:jakarta.servlet-api:5.0.0")
    implementation("jakarta.servlet:jakarta.servlet-api:6.0.0") // Or 5.0.0
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("mysql:mysql-connector-java:8.0.33")

    // For websockets
    val jettyVersion = "11.0.24"
    implementation("org.eclipse.jetty:jetty-server:${jettyVersion}")
    implementation("org.eclipse.jetty:jetty-servlet:${jettyVersion}")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-server:${jettyVersion}")
    implementation("org.eclipse.jetty.websocket:websocket-jetty-client:${jettyVersion}")




    implementation("com.google.code.gson:gson:2.10.1")

}

tasks.test {
    useJUnitPlatform()
}
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17)) // or 21 for JDK 21
    }
}

tasks.withType<KotlinCompile> {
    kotlinOptions.jvmTarget = "17" // Or "21" if using JDK 21
}



private fun DependencyHandlerScope.providedCompile(string: String) {}
