# Upstream

This lab reproduces one challenge — **Cheshire Cat** — from CI/CD Goat.

| What | Source | Licence |
| --- | --- | --- |
| The "Cheshire Cat" challenge (running a pipeline on the Jenkins controller via a pinned node, to read a secret from the controller's filesystem) | [CI/CD Goat](https://github.com/cider-security-research/cicd-goat) by Cider Security (now Palo Alto Networks), v1.2.7 | Apache-2.0 |
| Security classes | [OWASP CICD-SEC-4: Poisoned Pipeline Execution](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-04-Poisoned-Pipeline-Execution) · [CICD-SEC-5: Insufficient PBAC](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-05-Insufficient-PBAC) | — |

Only the *vulnerability* is reproduced, not upstream's eight-machine CI/CD stack. The lab is two
machines — a Jenkins controller and a Gitea git host — which is the minimum this attack needs: a
pipeline that builds a repository on push, a controller whose Built-In Node still has executors, and
a secret on the controller's filesystem.

Nothing is vendored from upstream. Upstream serves a copy of a real open-source project as the
`cheshire-cat` repository and bakes one fixed UUID flag onto the controller. This lab instead ships
an **original** minimal sample package (`build/gitea/repo-src/`, authored here, no third-party code)
with an original `Jenkinsfile`, and stages a **per-player** flag onto the controller's filesystem at
run time, so each player exfiltrates their own flag and nothing but the challenge idea comes from
upstream.

## The flag is a filesystem secret, not a credential

This is the point of Cheshire Cat, and the difference from the sibling *White Rabbit* lab. The flag
is **not** a Jenkins credential; it is a plain file, `~/flag5.txt` (`/root/flag5.txt`), owned by root
with mode `0400`, on the controller's own filesystem. It is reachable only by a process running on
the controller as root — i.e. a pipeline that executes on the **Built-In Node**. Jenkins runs as
root (`HOME=/root`), so a shell step on the controller can `cat` it; an agent, being a different
host, could not. The staging happens in the entrypoint from the per-player input Isoloom mounts at
`/run/lab/secrets/flag5`, so the flag is never an image layer, a spec value or an environment
variable.

## Faithful deviations

**The trigger.** Upstream wires the trigger with the Jenkins **Gitea** plugin: a Gitea SCM source
discovers *pull requests* (`PR-*`) and a periodic folder trigger rescans every minute. This lab uses
the Jenkins **git** plugin's multibranch source with *branch* discovery and the same one-minute
periodic rescan (an SCM poll, no inbound webhook). The attack and the player's steps are identical —
clone, repoint the `Jenkinsfile`'s agent to `built-in`, push a branch and open a pull request — but
the build is triggered by the pushed branch rather than by the PR object. This drops a Jenkins↔Gitea
plugin version dependency for a version-robust git poll, which matters for a lab family meant to run
unattended. The solver still opens the pull request, so the player-facing flow matches upstream.

**The dedicated agents.** Upstream runs a separate Jenkins agent container; ordinary jobs run there,
and the Built-In Node is reserved (and vulnerable). This two-machine lab has no agent machine: the
controller's Built-In Node is in **EXCLUSIVE** usage mode (it runs only jobs whose label matches it)
and still has executors. The repository's baseline `Jenkinsfile` targets `agent { label 'linux' }`,
representing those dedicated agents — which do not exist here, so the honest `main` build stays
pending. The vulnerability, the player's steps and the solver are unchanged: the attacker pins
`agent { label 'built-in' }` to land on the controller. If anything this sharpens the lesson — the
only way to get code execution in this lab is to escape onto the controller.

## A note on the exfiltration encoding

The attacker prints the file through `rev | base64` (then `base64 -d | rev` to recover it), the same
robust transform the sibling White Rabbit lab uses. Here the flag is a file `cat`, not a bound
credential, so Jenkins' credential masking does not apply; the transform is kept purely so the exfil
is a single, well-formed blob in the console regardless of the flag's bytes.
