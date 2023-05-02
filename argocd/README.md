# Helm으로 ArgoCD 설치하기

이전에 `deployment.yaml` 파일을 이용하여 애플리케이션을 실행하였는데, 실제 현업에서는 애프릴케이션을 실행하기 위해서는 쿠버네티스 리소스가 여러 개 필요한 경우가 많다. 또한 하나의 애플리케이션에는 Pod의 노출을 담당하는 Service, 설정과 관련된 ConfigMap, Secret 등이 포함된다. 이러한 리소스들을 각각 관리하지 않고 하나의 패키지로 관리하는 도구가 헬름(Helm)이다.

<br>

## 1. Helm의 주요 구성 요소

- 차트(Charts)는 여러 리소스의 묶음으로, 애플리케이션 설치에 필요한 네트워크, 스토리지, 보안 등과 관련된 쿠버네티스 리소스를 포함한다.
- 레포지토리(Repository)는 차트가 저장된 곳으로, 로컬 머신이나 원격 서버 등 다양한 곳에 위치할 수 있다.
- 템플릿(Templates)은 차트에 대한 설정을 담은 파일로, 동적으로 값이 할당될 수 있는 변수를 사용할 수 있다.

<br>

## 2. Helm으로 ArgoCD 설치
> Numble 챌린지를 참여하며 기존에 작성했던 [ArgoCD Templates](https://github.com/mustnot/numble-k8s-monitoring-system/tree/main/argocd)를 이용하는 방식으로 진행했습니다.

### 2.1. Helm 설치하기

실습 환경이 Mac이므로 `brew` 를 이용하여 설치를 진행, 다른 환경에서의 설치 방법은 [링크](https://helm.sh/ko/docs/intro/install/)를 참고한다.

```bash
$ brew install helm
```

<br>

### 2.2. Chart 정의하기

먼저 현재 폴더 구조는 다음과 같습니다. `templates` 폴더 아래에 `yaml` 파일들은 이후 관리를 위해 [argo-cd/manifests/install.yaml](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml) 파일을 용도에 맞게 분리한 파일들입니다.

```bash
# argocd/
├── templates
│   ├── cm.yaml
│   ├── crd.yaml
│   ├── deployment.yaml
│   ├── network.yaml
│   ├── permission.yaml
│   └── service.yaml
├── Chart.yaml
└── values.yaml
```

차트는 쿠버네티스 리소스와 관련된 셋을 설명하는 파일의 모음이지만, `templates`에 오브젝트 정의가 작성된 `yaml` 파일이 존재한다면, 아래와 같이 필수 요소만 작성해도 동작에는 이상이 없다.

> 아래 필드 외에 필드가 궁금하면 [링크](https://helm.sh/ko/docs/topics/charts/)를 참고한다.

```yaml
# Chart.yaml
apiVersion: v2
name: argocd
version: 0.1.0  # 버전은 목적에 맞춰 작성해도 된다.
```

<br>

### 2.3. Chart 설치

관리를 위해 `argocd`라는 네임스페이스를 생성한 후에 해당 네임스페이스 아래에 `helm install` 명령어를 이용하여 앞서 작성한 차트를 동작시킨다.

```bash
$ kubectl create namespace argocd
$ helm install argocd argocd/ --namespace argocd

# 만약 삭제를 원한다면, helm uninstall argocd 명령어로 삭제 가능하다.
```

### 2.4. ArgoCD 설치 및 접속

argocd가 설치되었더라도, 외부 접근에 대해 허용되지 않았기 때문에 port-forward 명령어를 통해 접근할 수 있도록 한다.

```bash
$ kubectl port-forward svc/argocd-server -n argocd 8080:443
```

정상적으로 실행이 되었다면 [https://localhost:8080](https://localhost:8080) 주소를 입력하여 페이지에 접근한다.

![image](https://user-images.githubusercontent.com/52126612/235593340-8ae942ac-9973-40f1-be80-e96e2160002d.png)

아직 생성된 계정이 없기 때문에 먼저 ArgoCD에 `initial-password` 명령어를 이용하여 admin 계정의 패스워드를 초기화하여 생성한다.

```bash
$ brew install argocd
$ argocd admin initial-password -n argocd
n4CmxERI...
```

이제 Username: admin / Password n4CmxERI... 로 접속이 가능하다.

로그인하여 ArgoCD 메인 화면에 접근하면 아래와 같은 화면을 볼 수 있다.

![image](https://user-images.githubusercontent.com/52126612/235593378-2bbbb955-48ad-438b-8635-49a6184f1529.png)

ArgoCD 첫 화면

### 부록. ArgoCD에 app of apps pattern을 이용하여 application을 추가한 경우

![image](https://user-images.githubusercontent.com/52126612/235593444-faf7cfc2-0f50-44df-a377-678099ec16ca.png)

로그인하여 ArgoCD 메인 화면에 접근하면 아래와 같은 화면을 볼 수 있다.
