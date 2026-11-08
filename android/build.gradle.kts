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

// Keep Android library plugins (including older transitive Flutter plugins such
// as isar_flutter_libs) on the same SDK as the application. Isar 3.x publishes
// resources that reference android:attr/lStar (API 31+).
subprojects {
    plugins.withId("com.android.library") {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            if (namespace.isNullOrEmpty()) {
                namespace = project.group.toString()
                    .ifEmpty { "com.example.${project.name.replace("-", "_")}" }
            }
            compileSdk = 36
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
