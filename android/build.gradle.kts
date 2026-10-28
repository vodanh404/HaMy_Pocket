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
            val androidExtension = extensions.findByName("android")
                ?: throw GradleException("onnxruntime Android extension was not found.")
            val sourceSetsGetter = androidExtension.javaClass.methods.firstOrNull {
                it.name == "getSourceSets" && it.parameterCount == 0
            } ?: throw GradleException("onnxruntime Android source sets were not found.")
            val sourceSets = sourceSetsGetter.invoke(androidExtension)
            val getMainSourceSet = sourceSets.javaClass.methods.firstOrNull {
                it.name == "getByName" && it.parameterCount == 1
            } ?: throw GradleException("onnxruntime main source set was not found.")
            val mainSourceSet = getMainSourceSet.invoke(sourceSets, "main")
            val jniLibsGetter = mainSourceSet.javaClass.methods.firstOrNull {
                it.name == "getJniLibs" && it.parameterCount == 0
            } ?: throw GradleException("onnxruntime JNI libraries were not found.")
            val jniLibs = jniLibsGetter.invoke(mainSourceSet)
            val setSourceDirectories = jniLibs.javaClass.methods.firstOrNull {
                it.name == "setSrcDirs" && it.parameterCount == 1
            } ?: throw GradleException("onnxruntime JNI source directories could not be configured.")
            // Sherpa bundles ONNX Runtime 1.23.2; omit this plugin's 1.15.1 copy.
            setSourceDirectories.invoke(jniLibs, emptyList<String>())

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
