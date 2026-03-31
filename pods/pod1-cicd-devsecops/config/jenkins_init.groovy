# =============================================================================
# Jenkins Initialization Script
# =============================================================================
# Author: Andrés M. Correa
# Description: Initial Jenkins configuration for CI/CD pipeline
# =============================================================================

import jenkins.model.*
import hudson.security.*
import org.jenkinsci.plugins.docker.workflow.Docker
import com.dabsquared.gitlabjenkins.connection.GitLabConnection
import com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig

def instance = Jenkins.getInstance()
def securityRealm = new HudsonPrivateSecurityRealm(false)
securityRealm.createAccount("admin", "${JENKINS_ADMIN_PASSWORD}")
instance.setSecurityRealm(securityRealm)

def authorizationStrategy = new global.GlobalMatrixAuthorizationStrategy()
authorizationStrategy.add(Jenkins.ADMINISTER, "admin")
instance.setAuthorizationStrategy(authorizationStrategy)

instance.save()

println "Jenkins initialized with admin user"