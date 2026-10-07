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
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val getNs = androidExt.javaClass.getMethod("getNamespace")
                if (getNs.invoke(androidExt) == null) {
                    val setNs = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = if (project.name == "flutter_app_badger") {
                        "fr.g123k.flutterappbadge.flutterappbadger"
                    } else {
                        "com.example.${project.name.replace('-', '_')}"
                    }
                    setNs.invoke(androidExt, ns)
                }
                val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                setCompileSdk.invoke(androidExt, 35)
            } catch (_: Exception) {}
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
