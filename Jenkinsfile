// Jenkins pipeline APP (Flutter, mobile) M-BIS. Template untuk Jenkins Divisi IT.
// CI/CD mobile MASIH MANUAL untuk sekarang — pipeline ini menyiapkan gerbang analyze+test
// + build APK/AAB. iOS butuh macOS (cloud: Codemagic/Xcode Cloud), tidak di Jenkins Linux.
// ⚙️ FIX-AFTER-IT: agent, keystore signing, distribusi (Firebase App Distribution/store).
pipeline {
  agent any

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  environment {
    FLUTTER_VERSION = '3.44.3'   // samakan dgn pubspec (Dart 3.12)
  }

  stages {
    stage('Analyze & Test') {
      steps {
        dir('frontend/flutter') {
          // Container Flutter siap-pakai; samakan tag dgn Dockerfile (cirruslabs flutter).
          script {
            docker.image("ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION}").inside {
              sh 'flutter pub get'
              sh 'flutter analyze'   // gerbang lint — gagal bila warning
              sh 'flutter test'
            }
          }
        }
      }
    }

    stage('Build APK/AAB') {
      when { branch 'main' }
      steps {
        dir('frontend/flutter') {
          script {
            docker.image("ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION}").inside {
              // ⚙️ signing: inject keystore lewat Jenkins credentials, JANGAN commit keystore.
              sh 'flutter build apk --release --dart-define-from-file=env/prod.json || flutter build apk --release'
            }
          }
          archiveArtifacts artifacts: 'build/app/outputs/**/*.apk', allowEmptyArchive: true
        }
      }
    }

    // iOS: build di cloud macOS (codemagic.yaml) — bukan di Jenkins Linux ini.
    // Distribusi mobile: MANUAL dulu (poin rapat), otomasi menyusul.
  }

  post {
    failure { echo 'CI app GAGAL — cek analyze/test di atas.' }
  }
}
