aviary-deploy
=============

IaC code to stand up a basic dev environment on a k8s cluster and an nfs server.

The Aviary platform gives engineers access to a suite of tools running in a compliant Kubernetes cluster.  Included are tools to store data, build software, and develop machine learning models.  The tools are exposed via ingress with internal ca signed certs.

Installing
==========

- git clone
- cd aviary-deploy
- edit to taste
- tofu init
- tofu apply
- set up gitea app for drone
- tofu apply again with the app keys
- add the following to your /etc/hosts file
```
10.23.99.7      ssh.gitea.local ssh.gitea
10.23.99.4      ing dbeaver.local pgoui.local grafana.local kibana.local ing.local kubeshark.local tempo.local wiki.local gitea.local gitea cloudtty.local bash.local shell.local kubernetes-dashboard.local dashboard.local minio.local minio-console.local prometheus.local velero.local drone.local harbor harbor.local
```
Notes
=====

Take care to preserve your PVCs when re-deploying.  

tofu destroy skips helm installs that are in progress.  Take a look at 
