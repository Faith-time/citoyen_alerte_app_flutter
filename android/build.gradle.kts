buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    layout.buildDirectory = rootProject.layout.buildDirectory.dir(project.name)
}

rootProject.layout.buildDirectory.set(file("../build"))

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}