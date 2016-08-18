#!groovy

node {
    env.DOCKER_USE_HUB = 1
    def deployable_branches = ["master", "next_release"]

    stage 'Checkout'
        checkout scm

    stage 'Docker build'
        echo "Branch is: ${env.BRANCH_NAME}"
        echo "Build is: ${env.BUILD_NUMBER}"
        wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
            sh './develop.sh build'
        }

    if (deployable_branches.contains(env.BRANCH_NAME)) {

        stage 'Publish docker image'
            withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'dockerbot',
                              usernameVariable: 'DOCKER_USERNAME',
                              passwordVariable: 'DOCKER_PASSWORD']]) {
                wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'XTerm']) {
                    sh './develop.sh ci_docker_login'
                    sh './develop.sh publish_docker_image'
                }
            }
    }
}
