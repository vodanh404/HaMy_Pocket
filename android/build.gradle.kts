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
// onnxruntime 1.4.1 pins compileSdk 33, below its resolved AndroidX requirements.
subprojects {
    plugins.withId("com.android.library") {
        if (name == "onnxruntime") {
            val androidComponents = extensions.findByName("androidComponents")
                ?: throw GradleException("onnxruntime Android Components extension was not found.")
            val finalizeDsl = androidComponents.javaClass.methods.firstOrNull {
                it.name == "finalizeDSl" && it.parameterCount == 1
            } ?: throw GradleException("onnxruntime DSL finalization is not available.")
            val configureCompileSdk = object : groovy.lang.Closure<Any>(this) {
                fun doCall(androidDsl: Any) {
                    val setCompileSdk = androidDsl::class.java.methods.firstOrNull {
                        it.name == "setCompileSdk" &&
                            it.parameterTypes.contentEquals(arrayOf(Int::class.javaObjectType))
                    } ?: throw GradleException("onnxruntime compileSdk could not be configured.")
                    setCompileSdk.invoke(androidDsl, 36)
                }
            }
            finalizeDsl.invoke(
                androidComponents,
                configureCompileSdk,
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
