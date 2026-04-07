allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val project = this
    if (project.name != "app") {
        afterEvaluate {
            if (project.hasProperty("android")) {
                val android = project.extensions.getByName("android")
                try {
                    val getNamespace = android.javaClass.methods.find { it.name == "getNamespace" }
                    val setNamespace = android.javaClass.methods.find { it.name == "setNamespace" && it.parameterTypes.size == 1 && it.parameterTypes[0] == String::class.java }
                    
                    if (getNamespace != null && setNamespace != null) {
                        val namespace = getNamespace.invoke(android)
                        if (namespace == null) {
                            // Try to read package from AndroidManifest.xml
                            val manifestFile = project.file("src/main/AndroidManifest.xml")
                            if (manifestFile.exists()) {
                                val manifestXml = manifestFile.readText()
                                val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestXml)
                                if (packageMatch != null) {
                                    val packageName = packageMatch.groupValues[1]
                                    setNamespace.invoke(android, packageName)
                                } else {
                                    setNamespace.invoke(android, "com.example.nirbhaya." + project.name.replace("-", "_"))
                                }
                            } else {
                                setNamespace.invoke(android, "com.example.nirbhaya." + project.name.replace("-", "_"))
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Fallback for older AGP versions
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
