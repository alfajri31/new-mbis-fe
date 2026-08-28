// fe-new-mbis (M-BIS Flutter Web) — analyze, test, build, scan, push, deploy.
//
// Shape follows fe-prime/be-prime, with ONE deliberate difference: the app is NOT compiled on the
// Jenkins agent. fe-prime uses the `nodejs` tool because Node is a Jenkins-managed tool; there is no
// equivalent Flutter tool here, and installing an SDK on the agent means every agent drifts. So the
// existing multi-stage `Dockerfile` does the compile inside `ghcr.io/cirruslabs/flutter`, and this
// pipeline only feeds it build-args. The analyze/test gate runs in that same image via `docker run`,
// so CI and the release build use one identical toolchain.
//
// Registry is Docker Hub under the `askrindo` namespace, same credential as the other Askrindo jobs.
//
// Two branches deploy and nothing else: `main` -> production, `testing` -> development/staging.
//
// Jenkins globals expected (set once, shared with the other Askrindo jobs):
//   TRIVY_URL, TRIVY_TOKEN
//   PROD_SSH_MBIS_HOST, PROD_SSH_MBIS_USER
//   DEV_SSH_MBIS_HOST,  DEV_SSH_MBIS_USER
// Optional:
//   PROD_API_URL_MBIS   — override the prod API prefix (default https://mbis.askrindo.co.id/v2)
//   DEV_API_URL_MBIS    — override the staging API base; leave UNSET for same-origin (recommended)
//   PROD_ENTRA_TENANT_ID / PROD_ENTRA_CLIENT_ID
//   DEV_ENTRA_TENANT_ID  / DEV_ENTRA_CLIENT_ID
//     Public Entra identifiers, safe in a client bundle. Unset -> the "Masuk dengan Microsoft"
//     button is hidden and local login is the only path. Not a failure, so this does not error.
// Credentials: dockerhub-auth (username/password), ssh-mbis-prod, ssh-mbis-dev (SSH key).
//
// **This pipeline ships an image and nothing else**, matching be-prime and the house pattern: the
// deploy stage is a single `docker service update --image`, and every runtime variable is set once
// on the Swarm service by `docker service create`.
//
// IMPORTANT — Flutter web has no runtime env. Every `--dart-define` is COMPILED INTO the bundle, and
// `--base-href` is written into index.html. Changing API_URL or the serving prefix therefore needs a
// REBUILD, not a `docker service update --env-add`. That is why the branch decides them below and
// why a wrong value here surfaces as a white screen or 403s in the browser, never as a build error.
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY_URL = "https://index.docker.io/v1/"
        IMAGE_NAME = "fe-new-mbis"
        HARBOR_PROJECT = "askrindo"
        DOCKER_AUTH_ID = "dockerhub-auth"

        // Swarm service to update. Deployed standalone rather than under a stack, so there is no
        // `<stack>_` prefix — if it is later moved into a stack this becomes `<stack>_fe-new-mbis`.
        SWARM_SERVICE = "fe-new-mbis"

        // Keep in sync with the Dockerfile's `ARG FLUTTER_VERSION`. cirruslabs lags patch releases:
        // the team's local SDK is 3.44.3 (Dart 3.12.2) but only 3.44.0 is published, which is why
        // pubspec's Dart floor is ^3.12.0. Check before bumping:
        //   docker manifest inspect ghcr.io/cirruslabs/flutter:3.44.3
        FLUTTER_VERSION = "3.44.0"
        FLUTTER_IMAGE = "ghcr.io/cirruslabs/flutter:3.44.0"

        // Container port. nginx.conf `listen 80` and the Dockerfile's EXPOSE — change all three
        // together. The published host port is set on the Swarm service, not here.
        APP_PORT = "80"

        // Backend port on the internal Docker network. nginx.conf proxies /api/ -> mbis-backend:3023
        // for staging; prod bypasses that proxy entirely via an absolute API_URL.
        BACKEND_PORT = "3023"

        // Visit dates, SLA windows and the "hari ini" filters are computed client-side; an unset TZ
        // on the container shows up as reports off by one day rather than as an error.
        TZ = "Asia/Jakarta"
    }

    stages {
        stage('Initialize Environment') {
            steps {
                script {
                    // Version comes from pubspec.yaml (`version: 1.0.1+9`) so a deployed container
                    // traces back to a commit's declared version — and to the same versionCode that
                    // went to Play, since web and mobile share this file. No `node -p` equivalent
                    // here, so read the first `version:` at column 0 (a nested `version:` under a
                    // dependency is indented and cannot match).
                    env.APP_VERSION = sh(
                            script: "grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//'",
                            returnStdout: true).trim()

                    if (!env.APP_VERSION) {
                        error "Aborting build: no `version` in pubspec.yaml."
                    }

                    // Docker tags allow [A-Za-z0-9_.-] only, so the `+build` separator becomes `-`:
                    // 1.0.1+9 -> 1.0.1-9. Side benefit over fe-prime: the build number is part of
                    // the tag, so bumping ONLY `+n` still produces a fresh, non-overwriting tag.
                    env.DOCKER_TAG_VERSION = env.APP_VERSION.replace('+', '-')

                    if (env.BRANCH_NAME == 'main') {
                        env.REMOTE_HOST = "${env.PROD_SSH_MBIS_HOST}"
                        env.SSH_AUTH_ID = "ssh-mbis-prod"
                        env.SSH_USER = "${env.PROD_SSH_MBIS_USER}"
                        env.SSH_PORT = "22"
                        env.APP_ENV = "prod"

                        // Prod splits ONE domain by path prefix (reverse proxy on the host, see
                        // docs/MIGRASI-DOMAIN-PROD-V2.md): /app/ -> this bundle, /v2/ -> backend.
                        // The proxy STRIPS the prefix, so the bundle must know both.
                        env.BASE_HREF = "/app/"
                        env.API_URL = env.PROD_API_URL_MBIS?.trim() ? env.PROD_API_URL_MBIS.trim()
                                                                   : "https://mbis.askrindo.co.id/v2"

                        env.ENTRA_TENANT_ID = env.PROD_ENTRA_TENANT_ID ?: ''
                        env.ENTRA_CLIENT_ID = env.PROD_ENTRA_CLIENT_ID ?: ''
                    } else if (env.BRANCH_NAME == 'testing') {
                        env.REMOTE_HOST = "${env.DEV_SSH_MBIS_HOST}"
                        env.SSH_AUTH_ID = "ssh-mbis-dev"
                        env.SSH_USER = "${env.DEV_SSH_MBIS_USER}"
                        env.SSH_PORT = "22"
                        env.APP_ENV = "staging"

                        // Staging is one stack, one origin: bundle at the root, and an EMPTY API_URL
                        // so AppConfig.apiBaseUrl falls back to same-origin and the browser hits
                        // /api/* on this very nginx, which proxies it to mbis-backend. Filling this
                        // in would make the calls cross-origin and require CORS on the backend.
                        env.BASE_HREF = "/"
                        env.API_URL = env.DEV_API_URL_MBIS?.trim() ? env.DEV_API_URL_MBIS.trim() : ""

                        env.ENTRA_TENANT_ID = env.DEV_ENTRA_TENANT_ID ?: ''
                        env.ENTRA_CLIENT_ID = env.DEV_ENTRA_CLIENT_ID ?: ''
                    } else {
                        error "Aborting build: Branch '${env.BRANCH_NAME}' is not allowed for deployment."
                    }

                    env.FULL_IMAGE_PATH = "${HARBOR_PROJECT}/${IMAGE_NAME}:${env.DOCKER_TAG_VERSION}"

                    // An unset Jenkins global interpolates as the literal string "null", which would
                    // otherwise ssh to a host named `null` several stages later, after a full Flutter
                    // compile has already been paid for.
                    if (!env.REMOTE_HOST?.trim() || env.REMOTE_HOST == 'null') {
                        error "Aborting build: REMOTE_HOST is unset for '${env.BRANCH_NAME}'. Check the *_SSH_MBIS_HOST global."
                    }

                    if (!env.SSH_USER?.trim() || env.SSH_USER == 'null') {
                        error "Aborting build: SSH_USER is unset for '${env.BRANCH_NAME}'. Check the *_SSH_MBIS_USER global."
                    }

                    // Same "null" trap, but far nastier: a literal null here is BAKED INTO the bundle
                    // and only shows up as failed API calls in the browser. Empty is legal (staging
                    // same-origin); the string "null" never is.
                    if (env.API_URL == 'null') {
                        error "Aborting build: API_URL resolved to the literal string 'null'. Check the *_API_URL_MBIS global."
                    }

                    // base-href without a trailing slash makes Flutter emit asset paths that 404 ->
                    // white screen, no error anywhere except the network tab.
                    if (!env.BASE_HREF.endsWith('/')) {
                        error "Aborting build: BASE_HREF ('${env.BASE_HREF}') must end with a slash."
                    }

                    if (!env.ENTRA_CLIENT_ID?.trim() || !env.ENTRA_TENANT_ID?.trim()) {
                        echo "NOTE: Entra SSO identifiers are unset for '${env.BRANCH_NAME}' — the Microsoft sign-in button will be hidden and local login used."
                    }

                    echo "Deploying ${IMAGE_NAME} v${env.APP_VERSION} (${env.APP_ENV}) -> ${env.REMOTE_HOST}, base-href ${env.BASE_HREF}, API '${env.API_URL ?: '(same-origin)'}'"
                }
            }
        }

        stage('Analyze & Test') {
            steps {
                // Run the gate in the SAME image the Dockerfile builds with, so a lint that passes
                // here cannot fail the release build on an SDK difference.
                //
                // Plain `docker run` rather than `docker.image().inside`: the Jenkins wrapper injects
                // `-u <uid>:<gid>`, and the cirruslabs SDK is checked out as root, so git refuses it
                // with "detected dubious ownership" before pub get ever runs.
                //
                // pub-cache is a named volume so ~200 packages are not re-downloaded every build.
                sh '''
                docker run --rm \
                    -v "$WORKSPACE":/app -w /app \
                    -v mbis-pub-cache:/root/.pub-cache \
                    -e PUB_CACHE=/root/.pub-cache \
                    --entrypoint sh \
                    $FLUTTER_IMAGE -c '
                        set -e
                        git config --global --add safe.directory /app
                        git config --global --add safe.directory /sdks/flutter
                        flutter pub get
                        flutter analyze
                        flutter test
                    '
                '''
            }
        }

        stage('Build Image') {
            steps {
                script {
                    echo "Building Docker image ${FULL_IMAGE_PATH} (compiling Flutter web inside the image)..."

                    // The Flutter compile happens HERE, so this stage is the slow one (~5-10 min
                    // cold). `pubspec.yaml`/`pubspec.lock` are copied before the rest of the source
                    // in the Dockerfile, so the `flutter pub get` layer is reused unless deps change.
                    //
                    // API_URL is intentionally passed even when empty — that empty value IS the
                    // staging same-origin config, not a missing one. Read through locals
                    // first: an env var set to "" can come back as null, and a null inside a
                    // GString interpolates as the four characters `null` — which would then be
                    // compiled into the bundle as a real API host and only fail in the browser.
                    def apiUrlArg = (env.API_URL == null || env.API_URL == 'null') ? '' : env.API_URL
                    def entraTenantArg = env.ENTRA_TENANT_ID ?: ''
                    def entraClientArg = env.ENTRA_CLIENT_ID ?: ''

                    sh """
                    docker build \
                        -t ${FULL_IMAGE_PATH} \
                        --build-arg FLUTTER_VERSION=${FLUTTER_VERSION} \
                        --build-arg APP_ENV=${APP_ENV} \
                        --build-arg BASE_HREF=${BASE_HREF} \
                        --build-arg API_URL=${apiUrlArg} \
                        --build-arg ENTRA_TENANT_ID=${entraTenantArg} \
                        --build-arg ENTRA_CLIENT_ID=${entraClientArg} \
                        -f Dockerfile .
                    """

                    // Guard against a silently empty bundle: `flutter build web` can exit 0 having
                    // written nothing useful if the build directory was fed from a stale cache, and
                    // the result is an nginx that 404s its own index.
                    sh """
                    docker run --rm --entrypoint sh ${FULL_IMAGE_PATH} -c \
                        'test -s /usr/share/nginx/html/index.html && test -s /usr/share/nginx/html/flutter_bootstrap.js' \
                        || { echo 'ERROR: built image has no Flutter web bundle.'; exit 1; }
                    """

                    // base-href is written into index.html at compile time. Verifying it here turns
                    // the single most common misconfiguration into a red build instead of a white
                    // screen that someone reports hours after the deploy.
                    sh """
                    docker run --rm --entrypoint cat ${FULL_IMAGE_PATH} /usr/share/nginx/html/index.html > index.deployed.html
                    grep -q 'base href="${BASE_HREF}"' index.deployed.html || { echo "ERROR: index.html base href is not ${BASE_HREF} - check the Dockerfile ARG BASE_HREF wiring."; exit 1; }
                    """
                }
            }
        }

        stage('Vulnerability Scan (Trivy)') {
            steps {
                script {
                    echo "Scanning image via Trivy Remote Server: ${FULL_IMAGE_PATH}"
                    sh """
                    trivy image --server ${env.TRIVY_URL} --token ${env.TRIVY_TOKEN} --severity HIGH,CRITICAL --scanners vuln --quiet ${FULL_IMAGE_PATH}
                    """
                }
            }
        }

        stage('Push Image') {
            steps {
                script {
                    docker.withRegistry(REGISTRY_URL, DOCKER_AUTH_ID) {
                        sh "docker push ${FULL_IMAGE_PATH}"
                    }
                }
            }
        }

        stage('Deploy to Docker Swarm') {
            steps {
                // Image only — no `--env-add`. The container is nginx serving static files; TZ and
                // the network attachment were set on the service by `docker service create` and
                // survive this update untouched. Everything the app itself reads is already inside
                // the bundle (see the note at the top of this file).
                withCredentials([usernamePassword(credentialsId: DOCKER_AUTH_ID, usernameVariable: 'H_USER', passwordVariable: 'H_PASS')]) {
                    sshagent([SSH_AUTH_ID]) {
                        sh '''
                    ssh -T -o StrictHostKeyChecking=no -p $SSH_PORT $SSH_USER@$REMOTE_HOST <<EOF

                    echo "$H_PASS" | docker login -u "$H_USER" --password-stdin $REGISTRY_URL

                    if [ \$? -eq 0 ]; then
                        echo "Login success, updating service..."
                        docker service update \
                            --image $FULL_IMAGE_PATH \
                            --with-registry-auth \
                            ${SWARM_SERVICE}
                    else
                        echo "Docker login failed!"
                        exit 1
                    fi
EOF
                '''
                    }
                }
            }
        }
    }

    post {
        always {
            // The Flutter container writes `.dart_tool/` and friends as root, so hand the workspace
            // back to the agent's user first — otherwise cleanWs() below hits EACCES and the next
            // build starts on a dirty checkout.
            sh 'docker run --rm -v "$WORKSPACE":/w alpine sh -c "chown -R $(id -u):$(id -g) /w" || true'

            // Local images pile up fast — a Flutter web image plus its build cache is ~2GB per tag.
            // `|| true` so a cleanup miss never turns a good deploy red.
            sh 'docker image rm -f $FULL_IMAGE_PATH || true'
            cleanWs()
        }
        failure {
            echo "Build FAILED for ${env.BRANCH_NAME} — check the Analyze & Test gate first, it fails on warnings."
        }
    }
}
