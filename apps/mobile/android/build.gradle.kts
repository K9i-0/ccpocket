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

// cargokit (irondash_engine_context, super_native_extensions) still calls
// Project.exec, which Gradle 9 removed. Groovy resolves a closure stored in an
// extra property as a method, so this restores it for their build tasks.
// Remove once cargokit uses ExecOperations (irondash/cargokit).
interface ExecOperationsProvider {
    @get:Inject
    val execOperations: ExecOperations
}

subprojects {
    val subproject = this
    val execOperations = objects.newInstance<ExecOperationsProvider>().execOperations
    extra["exec"] =
        object : groovy.lang.Closure<ExecResult>(subproject) {
            @Suppress("unused")
            fun doCall(configure: groovy.lang.Closure<*>): ExecResult =
                execOperations.exec { subproject.configure(this, configure) }
        }
}

// AGP 9 checks AAR metadata for library modules too. Plugins that still pin
// an old compileSdk (super_native_extensions: 31) fail against androidx
// dependencies that need 34+, so raise them to the app's level.
val minPluginCompileSdk = 36

subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            if ((compileSdk ?: minPluginCompileSdk) < minPluginCompileSdk) {
                compileSdk = minPluginCompileSdk
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
