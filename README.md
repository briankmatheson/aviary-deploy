aviary-deploy
=============

IaC code to stand up a basic dev environment on a k8s cluster and nfs server

- git clone
- cd aviary-deploy
- edit to taste
- tofu apply
- add the following to your /etc/hosts file

10.23.99.7      ssh.gitea.local ssh.gitea
10.23.99.4      ing dbeaver.local pgoui.local grafana.local kibana.local ing.local kubeshark.local tempo.local wiki.local gitea.local gitea cloudtty.local bash.local shell.local kubernetes-dashboard.local dashboard.local minio.local minio-console.local prometheus.local velero.local drone.local harbor harbor.local
