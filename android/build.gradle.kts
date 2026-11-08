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
    project.evaluationDependsOn(":app")
}

// Isar 3.1.0+1 predates AGP 8: it has no namespace and compiles
// against an SDK too old to provide android:attr/lStar. finalizeDsl runs
// after the plugin's own android block, so these values cannot be overwritten
// by the package's legacy build.gradle.
subprojects {
    if (name == "isar_flutter_libs") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.variant.AndroidComponentsExtension<*, *, *>>("androidComponents") {
                finalizeDsl { androidExtension ->
                    // The wildcard AndroidComponentsExtension type erases the
                    // DSL-specific properties in Kotlin. Cast to the library DSL
                    // used by this Android library module before setting them.
                    val libraryExtension =
                        androidExtension as com.android.build.gradle.LibraryExtension
                    libraryExtension.namespace = "dev.isar.isar_flutter_libs"
                    libraryExtension.compileSdk = 36
                }
            }
        }
    }

    configurations.all {
        resolutionStrategy {
            force("androidx.browser:browser:1.8.0")
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.core:core:1.13.1")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
