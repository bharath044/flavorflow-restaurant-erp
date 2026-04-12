buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
    }
}

import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force SDK 36 globally for all plugins
    project.extra.set("compileSdkVersion", 36)
    project.extra.set("targetSdkVersion", 36)
}

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null && android is com.android.build.gradle.BaseExtension) {
            android.compileSdkVersion(36)
        }
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core" && requested.name == "core") {
                useVersion("1.13.1")
            }
            if (requested.group == "androidx.core" && requested.name == "core-ktx") {
                useVersion("1.13.1")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}