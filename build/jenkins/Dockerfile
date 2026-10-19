# Wonderland's Jenkins controller. Configured entirely by Configuration-as-Code (casc/jenkins.yaml)
# with a Job DSL seed that creates the cheshire-cat multibranch pipeline. The flag is NOT here: it is
# a root-only file the entrypoint stages into the controller's home directory (~/flag5.txt) from the
# per-player input Isoloom mounts at run time. Jenkins runs as root with HOME=/root, so a pipeline
# that runs ON the controller's Built-In Node can read that root-only file — which is the whole point
# of the challenge (CICD-SEC-5: the controller's node should not run pipelines, but it still can).
FROM jenkins/jenkins:lts-jdk21

USER root

# Pin HOME so `~` resolves to /root everywhere: the entrypoint stages ~/flag5.txt there, and an
# `sh` step running on the Built-In Node (as root) resolves `cat ~/flag5.txt` to the same file.
ENV HOME=/root

# git + curl for the in-controller solver/self-check (the base image already ships git for SCM).
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Plugins (resolved for this controller version).
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Configuration-as-Code + the Job DSL seed, outside JENKINS_HOME so they are read as-is at boot.
COPY casc/ /usr/share/jenkins/casc/

COPY entrypoint.sh /usr/local/bin/cc-jenkins-entrypoint.sh
COPY solve.sh /usr/local/bin/cc-solve
RUN chmod 0755 /usr/local/bin/cc-jenkins-entrypoint.sh /usr/local/bin/cc-solve

ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc/jenkins.yaml \
    JAVA_OPTS="-Djenkins.install.runSetupWizard=false -Xmx1024m"

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/cc-jenkins-entrypoint.sh"]
