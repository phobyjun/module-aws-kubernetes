output "eks_cluster_id" {
  value = aws_eks_cluster.js-eks-cluster.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.js-eks-cluster.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.js-eks-cluster.certificate_authority.0.data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.js-eks-cluster.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.js-node-group.id
}
