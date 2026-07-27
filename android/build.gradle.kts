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

// Sebagian plugin lama (mis. file_picker 8.x) masih meng-hardcode compileSdk 34,
// sementara flutter_plugin_android_lifecycle 2.0.35 menuntut konsumennya dikompilasi
// di SDK 36. Samakan SEMUA subproject Android ke compileSdk 36 (app sendiri sudah 36).
// Refleksi dipakai agar skrip build root tidak perlu tipe AGP di classpath-nya dan
// tetap kompatibel lintas versi Android Gradle Plugin.
subprojects {
    val forceCompileSdk: () -> Unit = {
        extensions.findByName("android")?.let { ext ->
            listOf<() -> Unit>(
                { ext.javaClass.getMethod("setCompileSdk", Integer::class.java).invoke(ext, 36) },
                { ext.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType).invoke(ext, 36) },
                { ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36) }
            ).firstOrNull { runCatching { it() }.isSuccess }
                ?: logger.warn("compileSdk 36 gagal dipaksakan untuk subproject ${project.name}")
        }
    }
    // :app sudah dievaluasi (evaluationDependsOn di atas) → set langsung; sisanya
    // ditunda hingga setelah build script plugin masing-masing selesai dievaluasi.
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
