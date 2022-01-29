provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

resource "aws_iam_role" "js-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}

resource "aws_iam_role_policy_attachment" "js-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.js-cluster.name
}

resource "aws_security_group" "js-cluster" {
  name   = local.cluster_name
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "js-eks-cluster"
  }
}

resource "aws_eks_cluster" "js-eks-cluster" {
  name     = local.cluster_name
  role_arn = aws_iam_role.js-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.js-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.js-cluster-AmazonEKSClusterPolicy
  ]
}

# Node Role
resource "aws_iam_role" "js-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}

# Node Policy
resource "aws_iam_role_policy_attachment" "js-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.js-node.name
}

resource "aws_iam_role_policy_attachment" "js-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.js-node.name
}

resource "aws_iam_role_policy_attachment" "js-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.js-node.name
}

resource "aws_eks_node_group" "js-node-group" {
  cluster_name    = aws_eks_cluster.js-eks-cluster.name
  node_group_name = "microservices"
  node_role_arn   = aws_iam_role.js-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.js-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.js-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.js-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Create a kubeconfig file based on the cluster that has been created
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG_END
  apiVersion: v1
  clusters:
  - cluster:
    "certificate-authority-data: >
    ${aws_eks_cluster.js-eks-cluster.certificate_authority.0.data}
    server: ${aws_eks_cluster.js-eks-cluster.endpoint}
    name: ${aws_eks_cluster.js-eks-cluster.arn}
  contexts:
  - context:
    cluster: ${aws_eks_cluster.js-eks-cluster.arn}
    user: ${aws_eks_cluster.js-eks-cluster.arn}
    name: ${aws_eks_cluster.js-eks-cluster.arn}
  current-context: ${aws_eks_cluster.js-eks-cluster.arn}
  kind: Config
  preferences: {}
  users:
  - name: ${aws_eks_cluster.js-eks-cluster.arn}
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1alpha1
        command: aws-iam-authenticator
        args:
          - "token"
          - "-i"
          - "${aws_eks_cluster.js-eks-cluster.name}"
  KUBECONFIG_END
  filename = "kubeconfig"
}
