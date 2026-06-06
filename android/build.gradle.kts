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
    val configureProject = { proj: Project ->
        val android = proj.extensions.findByName("android")
        if (android != null) {
            val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val setNamespace = android.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 && it.parameterTypes[0] == String::class.java }
            if (getNamespace != null && setNamespace != null) {
                val currentNamespace = getNamespace.invoke(android) as String?
                if (currentNamespace.isNullOrEmpty()) {
                    var pkgName: String? = null
                    val manifestFile = proj.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        val matcher = java.util.regex.Pattern.compile("package=\"([^\"]+)\"").matcher(manifestText)
                        if (matcher.find()) {
                            pkgName = matcher.group(1)
                        }
                    }
                    if (pkgName == null) {
                        pkgName = "com.shcare.${proj.name.replace(":", "").replace("-", "")}"
                    }
                    setNamespace.invoke(android, pkgName)
                    println("🔧 Injected namespace '$pkgName' for project :${proj.name}")
                }
            }

            // Force Android compileOptions to Java 17
            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSourceCompatibility = compileOptions.javaClass.methods.firstOrNull { it.name == "setSourceCompatibility" }
                val setTargetCompatibility = compileOptions.javaClass.methods.firstOrNull { it.name == "setTargetCompatibility" }
                val javaVersion17 = org.gradle.api.JavaVersion.VERSION_17
                if (setSourceCompatibility != null && setTargetCompatibility != null) {
                    setSourceCompatibility.invoke(compileOptions, javaVersion17)
                    setTargetCompatibility.invoke(compileOptions, javaVersion17)
                    println("🔧 Set Java compatibility VERSION_17 for project :${proj.name}")
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }

    if (state.executed) {
        configureProject(this)
    } else {
        afterEvaluate {
            configureProject(this)
        }
    }

    tasks.configureEach {
        if (this.name.contains("compile") && this.name.contains("Kotlin")) {
            try {
                val kotlinOptions = this.javaClass.getMethod("getKotlinOptions").invoke(this)
                val setJvmTarget = kotlinOptions.javaClass.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "17")
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

