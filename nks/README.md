## 1. NCloud API 인증키 생성

- NCloud 포털 → 마이페이지 → 계정 관리 → 인증키 관리
    - 환경변수를 통해서 AccessKey와 SecretKey를 등록한다.
    
    ```bash
    $ echo 'export NCLOUD_ACCESS_KEY=<access_key>' >> ~/.zshrc
    $ echo 'export NCLOUD_SECRET_KEY=<secret_key>' >> ~/.zshrc
    $ echo 'export NCLOUD_REGION=KR' >> ~/.zshrc
    ```

<br>

## 2. Use Ncloud Terraform Provider

> 앞서 설정한 것처럼 환경 변수에 인증키가 저장되어있다면, 파일 내부에 키 값을 입력하지 않아도 된다.

- `versions.tf` 파일을 생성한 후에 아래 `provider`를 정의한다.
    
    ```terraform
    terraform {
      required_providers {
        ncloud = {
            source = "NaverCloudPlatform/ncloud"
        }
      }
      required_version = ">= 0.13"
    }
    
    // Configure the Ncloud Provider
    provider "ncloud" {
    	support_vpc = true
    }
    ```
    

<br>

## 3. Create Kubernetes Service Cluster

> 실제 콘솔 내 화면과 비교하며 이해하면 더 좋습니다.


<br>


### 1) VPC 및 Subnet 생성

```terraform
// main.tf
resource "ncloud_vpc" "vpc" {
  name            = "vpc"
  ipv4_cidr_block = "10.0.0.0/16"
}

resource "ncloud_subnet" "node_subnet" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "10.0.1.0/24"
  zone           = "KR-1"
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  name           = "node-subnet"
  usage_type     = "GEN"
}

resource "ncloud_subnet" "lb_subnet" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "10.0.100.0/24"
  zone           = "KR-1"
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PRIVATE"
  name           = "lb-subnet"
  usage_type     = "LOADB"
}
```

- 클러스터를 생성하기 전에 VPC를 생성하고, VPC 아래 Subnet과 LB Private Subnet을 생성합니다.

<br>

### 2) 클러스터 및 인증키 설정

```terraform

data "ncloud_nks_versions" "version" {
  filter {
    name = "value"
    values = ["1.24.10"]
    regex = true
  }
}

resource "ncloud_login_key" "loginkey" {
  key_name = "numble-cluster-key"
}

resource "ncloud_nks_cluster" "cluster" {
  cluster_type                = "SVR.VNKS.STAND.C004.M016.NET.SSD.B050.G002"
  k8s_version                 = data.ncloud_nks_versions.version.versions.0.value
  login_key_name              = ncloud_login_key.loginkey.key_name
  name                        = "numble-cluster"
  lb_private_subnet_no        = ncloud_subnet.lb_subnet.id
  kube_network_plugin         = "cilium"
  subnet_no_list              = [ ncloud_subnet.node_subnet.id ]
  vpc_no                      = ncloud_vpc.vpc.id
  zone                        = "KR-1"
  log {
    audit = true
  }
}
```

- ncloud_nks_versions
    - kubernetes 버전을 위한 data source입니다.
    - (23. 04. 12 기준) 1.24.10과 1.23.16 두 개 버전을 제공합니다.
- ncloud_login_key
    - 인증키 설정을 위한 Resource로 이미 생성한 key가 존재한다면, 생략하고 하단 login_key_name에 기존 key의 이름을 입력하면 됩니다.
- ncloud_nks_cluster
    - kubernetes 클러스터를 생성합니다.
    - 앞서 생성한 VPC와 Subnet, LB Private Subnet이 모두 설정에 포함합니다.

<br>

### 3) 노드 풀 설정

```terraform
data "ncloud_server_image" "image" {
  filter {
    name = "product_name"
    values = ["ubuntu-20.04"]
  }
}

data "ncloud_server_product" "product" {
  server_image_product_code = data.ncloud_server_image.image.product_code

  filter {
    name = "product_type"
    values = [ "STAND" ]
  }

  filter {
    name = "cpu_count"
    values = [ 4 ]
  }

  filter {
    name = "memory_size"
    values = [ "16GB" ]
  }

  filter {
    name = "product_code"
    values = [ "SSD" ]
    regex = true
  }
}

resource "ncloud_nks_node_pool" "node_pool" {
  cluster_uuid = ncloud_nks_cluster.cluster.uuid
  node_pool_name = "node-01"
  node_count     = 1
  product_code   = data.ncloud_server_product.product.product_code
  subnet_no      = ncloud_subnet.node_subnet.id
  autoscale {
    enabled = true
    min = 1
    max = 1
  }
}
```

- 쿠버네티스 클러스터의 노드를 구성하기 위한 설정 작업입니다.
- ncloud_server_image
    - 노드의 서버를 구성하기 위한 이미지를 지정하는 data source 입니다.
- ncloud_server_product
    - 지정한 이미지와 함께 cpu 개수, 메모리 사이즈, 디스크 종류를 지정하는 data source 입니다.
- ncloud_nks_node_pool
    - 노드에 대한 이름을 지정하고, auto scaling 설정과 개수를 지정합니다.

<br>

### 4. 실행

```bash
$ terraform init
$ terraform plan
$ terraform apply

ncloud_login_key.loginkey: Refreshing state... [id=numble-cluster-key]
data.ncloud_server_image.image: Reading...
ncloud_vpc.vpc: Refreshing state... [id=37186]
data.ncloud_nks_versions.version: Reading...
...
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:  yes

ncloud_nks_cluster.cluster: Creating...
ncloud_nks_cluster.cluster: Still creating... [10s elapsed]
ncloud_nks_cluster.cluster: Still creating... [20s elapsed]
ncloud_nks_cluster.cluster: Still creating... [30s elapsed]
```

- 모든 명령어를 실행하면 아래 이미지와 같이 클러스터가 자동으로 생성됩니다.

![image](https://user-images.githubusercontent.com/52126612/231485574-b3b809d4-be60-448f-96b0-17d35902e420.png)
