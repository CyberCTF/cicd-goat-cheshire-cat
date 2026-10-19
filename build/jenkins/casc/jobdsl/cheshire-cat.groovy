// Seed job (run by Configuration-as-Code) that creates Wonderland's cheshire-cat pipeline.
//
// A multibranch Pipeline backed by the Gitea repository over git. Branch discovery means every
// branch that carries a Jenkinsfile gets its own pipeline, built automatically when indexing finds
// it; a periodic rescan (every minute) is the SCM-poll trigger, so a pushed branch / opened PR runs
// without any inbound webhook. This is what makes the attack possible: whoever can push a branch
// controls the Jenkinsfile — including which node (agent) it pins — that the controller then runs.
multibranchPipelineJob('wonderland-cheshire-cat') {
    displayName('Wonderland » cheshire-cat')
    branchSources {
        branchSource {
            source {
                git {
                    id('wonderland-cheshire-cat')
                    remote('http://gitea:3000/Wonderland/cheshire-cat.git')
                    credentialsId('gitea-jenkins')
                    traits {
                        gitBranchDiscovery()
                    }
                }
            }
        }
    }
    factory {
        workflowBranchProjectFactory {
            scriptPath('Jenkinsfile')
        }
    }
    orphanedItemStrategy {
        discardOldItems {
            numToKeep(20)
        }
    }
    triggers {
        periodicFolderTrigger {
            interval('1m')
        }
    }
}
