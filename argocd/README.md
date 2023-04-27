# ArgoCD with Helm

## ArgoCD 설치
```bash
$ kubectl create namespace argocd
$ helm install argocd argocd/ -n argocd
```

## ArgoCD 실행 방법
```bash
$ kubectl port-forward svc/argocd-server -n argocd 8080:443
$ argocd admin initial-password -n argocd
```
