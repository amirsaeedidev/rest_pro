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
                    // Avoid casting AGP's decorated DSL implementation: in some
                    // Gradle classloader layouts it is not cast-compatible with
                    // the LibraryExtension class loaded by this build script.
                    val dsl = androidExtension as Any
                    val namespaceSetter = dsl.javaClass.methods.firstOrNull {
                        it.name == "setNamespace" && it.parameterCount == 1
                    } ?: error("Isar Android DSL does not expose setNamespace")
                    namespaceSetter.invoke(dsl, "dev.isar.isar_flutter_libs")

                    val compileSdkSetter = dsl.javaClass.methods.firstOrNull {
                        it.name == "setCompileSdk" &&
                            it.parameterTypes.contentEquals(arrayOf(Int::class.javaPrimitiveType))
                    } ?: error("Isar Android DSL does not expose setCompileSdk(int)")
                    compileSdkSetter.invoke(dsl, 36)
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
