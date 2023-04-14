provider "ncloud" {
  support_vpc = true
}

// default settings
resource "ncloud_vpc" "vpc" {
  name            = "vpc"
  ipv4_cidr_block = "10.0.0.0/16"
}

resource "ncloud_nat_gateway" "nat" {
  vpc_no = ncloud_vpc.vpc.id
  name   = "nat"
  zone   = "KR-1"
}

resource "ncloud_login_key" "loginkey" {
  key_name = "login-key-numble"
}

resource "local_file" "ssh_key" {
  filename = "${ncloud_login_key.loginkey.key_name}.pem"
  content = ncloud_login_key.loginkey.private_key
}

// server image settings
data "ncloud_server_image" "ubuntu_image" {
  filter {
    name = "product_name"
    values = ["ubuntu-20.04"]
  }
}

// kubernetes cluster settings
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

data "ncloud_nks_versions" "version" {
  filter {
    name = "value"
    values = ["1.24.10"]
    regex = true
  }
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

data "ncloud_server_product" "node_product" {
  server_image_product_code = data.ncloud_server_image.ubuntu_image.product_code

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
  cluster_uuid    = ncloud_nks_cluster.cluster.uuid
  node_pool_name  = "numble-node-pool"
  node_count      = 1
  product_code    = data.ncloud_server_product.node_product.product_code
  subnet_no       = ncloud_subnet.node_subnet.id
  autoscale {
    enabled = false
    min = 1
    max = 1
  }
}

// for kubernetes cluster to access internet
data "ncloud_route_table" "route_table" {
  vpc_no                = ncloud_vpc.vpc.id
  supported_subnet_type = "PRIVATE"
}

resource "ncloud_route" "route_table" {
  route_table_no          = data.ncloud_route_table.route_table.id
  destination_cidr_block  = "0.0.0.0/0"
  target_type             = "NATGW"
  target_name             = ncloud_nat_gateway.nat.name
  target_no               = ncloud_nat_gateway.nat.id
}

// Bastion Server
resource "ncloud_subnet" "public_subnet" {
  vpc_no         = ncloud_vpc.vpc.id
  subnet         = "10.0.2.0/24"
  zone           = "KR-1"
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "GEN"
}

data "ncloud_server_product" "bastion" {
  server_image_product_code = data.ncloud_server_image.ubuntu_image.product_code

  filter {
    name = "product_type"
    values = [ "STAND" ]
  }

  filter {
    name = "cpu_count"
    values = [ 2 ]
  }

  filter {
    name = "memory_size"
    values = [ "8GB" ]
  }

  filter {
    name = "product_code"
    values = [ "SSD" ]
    regex = true
  }
}

resource "ncloud_server" "bastion" {
  name                      = "numble-bastion"
  subnet_no                 = ncloud_subnet.public_subnet.id
  server_image_product_code = data.ncloud_server_image.ubuntu_image.product_code
  server_product_code       = data.ncloud_server_product.bastion.product_code
  login_key_name            = ncloud_login_key.loginkey.key_name
}

resource "ncloud_public_ip" "bastion" {
  server_instance_no = ncloud_server.bastion.id
}
