plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
    id("com.google.firebase.crashlytics") version "3.0.7" apply false
    id("com.google.firebase.firebase-perf") version "2.0.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Align every plugin module on Java 17, the version the app compiles at.
    //
    // receive_sharing_intent 1.8.1 — the last release with a CocoaPods
    // podspec, so the one this project has to use — declares Java 8 in its own
    // module while Kotlin 2.4 compiles it at 17, and AGP refuses the mismatch:
    //
    //   Execution failed for task ':receive_sharing_intent:compileDebugKotlin'
    //   > Inconsistent JVM-target compatibility detected for tasks
    //     'compileDebugJavaWithJavac' (1.8) and 'compileDebugKotlin' (17)
    //
    // Raising Java rather than lowering Kotlin keeps one toolchain across the
    // build, and covers any other plugin shipping the same stale default.
    //
    // `plugins.withId` rather than `afterEvaluate`: the line below forces
    // evaluation, so an afterEvaluate hook registered here would arrive too
    // late and Gradle would fail with "Cannot run Project.afterEvaluate(Action)
    // when the project is already evaluated."
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
