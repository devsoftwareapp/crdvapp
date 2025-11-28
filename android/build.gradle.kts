// ✅ Android ve Kotlin Gradle plugin tanımları
buildscript {
    dependencies {
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Tüm alt projelerde kullanılacak repository'ler
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Build dizinlerini kök build klasörüne taşı
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// ✅ Her alt proje için özel build klasörü tanımla
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// ✅ App projesine bağımlılığı tanımla
subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Clean komutu
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
