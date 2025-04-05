#########################################
# Security Group for EKS Cluster
#########################################

resource "aws_security_group" "cluster_control_plane" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.cluster_name}-cluster-control-plane"
  description = "Communication between the control plane and worker nodegroups"
  vpc_id      = var.vpc_id

  #######################################
  # Egress Rules
  #######################################

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      "Name" = "${var.cluster_name}-cluster-control-plane"
    },
    var.tags
  )
}

resource "aws_security_group" "cluster_nodes" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.cluster_name}-cluster-nodes"
  description = "Communication between all nodes in the cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow nodes to communicate with each other (all ports)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow managed and unmanaged nodes to communicate with each other (all ports)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    security_groups = [
      aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name" = "${var.cluster_name}-cluster-nodes"
    },
    var.tags
  )
}
