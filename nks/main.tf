provider "ncloud" {
  support_vpc = true
}

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

resource "ncloud_nat_gateway" "nat" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "nat"
  zone   = "KR-1"
}

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
    enabled = false
    min = 1
    max = 1
  }
}
