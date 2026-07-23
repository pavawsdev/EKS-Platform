data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  vpc_id      = var.vpc_id
  description = "Bastion host security group - SSH access only from allowed CIDRs"

  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # 443/80 covers SSM, package updates (dnf), EKS API, and downloading
  # kubectl/helm - the bastion never needs unrestricted outbound.
  egress {
    description = "HTTPS outbound (SSM, EKS API, package repos, kubectl/helm downloads)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound (package repo redirects)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "bastion_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name_prefix}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume.json
  tags               = var.tags
}

# SSM Session Manager access instead of open SSH where possible
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Least-privilege EKS describe access so the bastion can generate kubeconfig.
# eks:DescribeCluster is scoped to this specific cluster's ARN.
# eks:ListClusters has no resource-level permissions in AWS's IAM
# model (it's an account-wide list action), so it must stay on "*".
#checkov:skip=CKV_AWS_355:eks:ListClusters has no resource-level permissions in AWS's IAM model - it's an account-wide list action, "*" is the only valid Resource per AWS docs
resource "aws_iam_role_policy" "bastion_eks_describe" {
  name = "${var.name_prefix}-bastion-eks-describe"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:ListClusters"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = false
  monitoring                  = true # detailed (1-min) CloudWatch monitoring
  ebs_optimized               = true

  metadata_options {
    http_tokens   = "required" # IMDSv2 enforced
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y bash-completion
    curl -o /usr/local/bin/kubectl -L "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
    curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  EOF

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
  })
}
