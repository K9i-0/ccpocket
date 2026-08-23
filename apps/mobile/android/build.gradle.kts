// Firebase Messaging 25.1.2 fixes FCM registration failures caused by reused
// Firebase installation IDs. Remove this override once FlutterFire pins a
// Firebase Android BoM version 34.18.0 or newer.
rootProject.extra["FlutterFire"] = mapOf(
    "FirebaseSDKVersion" to "34.18.0",
)

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
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
