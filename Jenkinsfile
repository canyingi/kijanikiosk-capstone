// My capstone delivery pipeline (Track A)
//
//   merge to main -> test -> build + push image -> deploy STAGING -> smoke test STAGING
//        -> [approval: who + why is recorded] -> deploy PRODUCTION -> check PRODUCTION
//
// The most important rule: the production approval is only OFFERED after staging passes.
// If staging fails, the pipeline rolls staging back and stops. Production is never touched.
//
// What this needs on the Jenkins machine (my laptop - see README):
//   - a Pipeline job "kijanikiosk-capstone" reading this file from the main branch
//   - docker, kubectl (context minikube) and jq. Node runs inside a container instead.
//   - a Jenkins credential called 'dockerhub-creds' (Docker Hub username + access token)

pipeline {
  agent any

  // GitHub can't send a webhook to Jenkins on my laptop without opening it to the internet.
  // So Jenkins checks GitHub every 2 minutes instead - see docs/decisions/ADR-003-polling-vs-webhook.md
  triggers { pollSCM('H/2 * * * *') }

  options {
    timestamps()
    disableConcurrentBuilds()          // two runs must never deploy on top of each other
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 60, unit: 'MINUTES') // this includes the time spent waiting for approval
  }

  environment {
    IMAGE_REPO   = 'docker.io/canyingi/kk-payments'
    STAGING_NS   = 'kijani-staging'
    PROD_NS      = 'default'
  }

  stages {
    stage('Preflight') {
      steps {
        sh '''
          set -e
          test "$(kubectl config current-context)" = "minikube" || { echo "wrong kube context"; exit 1; }
          kubectl get namespace "$STAGING_NS" >/dev/null
          for t in docker jq kubectl; do command -v $t >/dev/null || { echo "missing tool: $t"; exit 1; }; done
          curl -s --max-time 2 -o /dev/null http://localhost:4569/ || { echo "receipt chain is not running - start it with 'make chain'"; exit 1; }
        '''
        script {
          def version = sh(script: "jq -r .version app/package.json", returnStdout: true).trim()
          env.IMAGE_TAG = "${version}-${env.GIT_COMMIT.substring(0, 7)}"
          env.IMAGE     = "${env.IMAGE_REPO}:${env.IMAGE_TAG}"
          currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Lint & Test') {
      steps {
        // Runs in the same Node image my Dockerfile uses, so Jenkins doesn't need Node installed.
        // The code is streamed in as a tar archive instead of mounted with -v, because my Docker
        // daemon (snap) cannot see /var/lib/jenkins (first pipeline run failed with 'read-only file system').
        sh '''
          tar -C app --exclude=node_modules -cf - . | docker run --rm -i node:20.18.0-alpine \
            sh -c "mkdir -p /app && cd /app && tar -xf - && npm ci --no-audit --no-fund && npm run lint && npm test"
        '''
      }
    }

    stage('Build & Push Image') {
      steps {
        dir('app') {
          sh 'docker build --build-arg APP_VERSION="$IMAGE_TAG" -t "$IMAGE" .'
        }
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                         usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
          sh '''
            echo "$DH_TOKEN" | docker login -u "$DH_USER" --password-stdin
            docker push "$IMAGE"
            docker logout
          '''
        }
      }
    }

    stage('Deploy to Staging') {
      steps {
        script { env.STAGING_TOUCHED = 'true' }
        sh 'scripts/deploy.sh "$STAGING_NS" "$IMAGE"'
      }
    }

    stage('Smoke Test Staging') {
      steps {
        sh 'scripts/smoke-test.sh "$STAGING_NS" "$IMAGE_TAG" | tee smoke-staging.log'
      }
      post { always { archiveArtifacts artifacts: 'smoke-staging.log', allowEmptyArchive: true } }
    }

    stage('Approve Production') {
      // Known limitation: this keeps a Jenkins executor busy while it waits. That's fine on my
      // single-user laptop; a shared Jenkins would need a different agent setup.
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          script {
            def approval = input(
              message: "Staging passed for ${env.IMAGE_TAG}. Promote to PRODUCTION?",
              ok: 'Promote to production',
              submitter: 'canyingi',   // C1 least privilege: only named approvers can release to production
              submitterParameter: 'APPROVER',
              parameters: [
                string(name: 'REASON', defaultValue: '',
                       description: 'Required: why is this safe to release? (e.g. "smoke test passed; fixes #12; no schema change")')
              ])
            def reason = (approval.REASON ?: '').trim()
            if (reason.length() < 10) {
              error("Approval rejected: a reason of at least 10 characters is required")
            }
            env.APPROVER        = approval.APPROVER
            env.APPROVAL_REASON = reason
          }
        }
      }
    }

    stage('Deploy to Production') {
      steps {
        // jq --arg treats the reason as plain text, so whatever someone types can't run as a command.
        sh '''
          jq -n --arg build "$BUILD_TAG" --arg image "$IMAGE" --arg approver "$APPROVER" \
                --arg reason "$APPROVAL_REASON" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{build:$build, image:$image, approver:$approver, reason:$reason, approved_at:$at}' \
                > approval-record.json
          cat approval-record.json
        '''
        archiveArtifacts artifacts: 'approval-record.json'
        script { env.PROD_TOUCHED = 'true' }
        sh '''
          scripts/deploy.sh "$PROD_NS" "$IMAGE"
          kubectl -n "$PROD_NS" annotate deployment/kk-payments --overwrite \
            "kijanikiosk.io/approved-by=$APPROVER" \
            "kijanikiosk.io/approval-reason=$APPROVAL_REASON" \
            "kijanikiosk.io/approved-build=$BUILD_TAG"
        '''
      }
    }

    stage('Verify Production') {
      steps {
        sh 'scripts/smoke-test.sh "$PROD_NS" "$IMAGE_TAG" | tee smoke-production.log'
      }
      post { always { archiveArtifacts artifacts: 'smoke-production.log', allowEmptyArchive: true } }
    }
  }

  post {
    failure {
      script {
        // If this run changed an environment and then failed, put it back to the last version
        // that worked, so the next person finds it working.
        if (env.PROD_TOUCHED == 'true') {
          // maxUnavailable: 0 means the old pods kept serving during the failed rollout.
          sh '''
            echo "Rolling back $PROD_NS to previous revision"
            kubectl -n "$PROD_NS" rollout undo deployment/kk-payments || true
            kubectl -n "$PROD_NS" rollout status deployment/kk-payments --timeout=120s || true
          '''
        } else if (env.STAGING_TOUCHED == 'true') {
          sh '''
            echo "Rolling back $STAGING_NS to previous revision"
            kubectl -n "$STAGING_NS" rollout undo deployment/kk-payments || true
            kubectl -n "$STAGING_NS" rollout status deployment/kk-payments --timeout=120s || true
          '''
        }
      }
      echo "Pipeline FAILED (see the red stage above). Production was ${env.PROD_TOUCHED ? 'rolled back' : 'NOT touched'}."
    }
    success {
      echo "Released ${env.IMAGE} to production. Approved by ${env.APPROVER}: ${env.APPROVAL_REASON}"
    }
  }
}
