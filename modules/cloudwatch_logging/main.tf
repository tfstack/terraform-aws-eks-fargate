#########################################
# CloudWatch Log Group
#########################################

resource "aws_cloudwatch_log_group" "fluentbit_logs_with_prevent_destroy" {
  count = var.enabled && var.log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/fluent-bit"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-fluentbit-logs"
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "fluentbit_logs_without_prevent_destroy" {
  count = var.enabled && !var.log_prevent_destroy ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/fluent-bit"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(
    {
      Name = "${var.cluster_name}-fluentbit-logs"
    },
    var.tags
  )
}

#########################################
# Fluent Bit ConfigMap for Fargate Logging
#########################################

resource "kubernetes_config_map" "aws_logging" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "aws-logging"
    namespace = "aws-observability"

    annotations = {
      "kubectl.kubernetes.io/last-applied-configuration" = jsonencode({
        apiVersion = "v1"
        kind       = "ConfigMap"
        metadata = {
          name        = "aws-logging"
          namespace   = "aws-observability"
          annotations = {}
        }
        data = {
          "output.conf" = trimspace(<<-EOT
            [OUTPUT]
                Name cloudwatch_logs
                Match *
                region ${var.region}
                log_group_name /aws/eks/${var.cluster_name}/fluent-bit
                log_stream_prefix from-fluent-bit-
                auto_create_group true
          EOT
          )
        }
      })
    }
  }

  data = {
    "output.conf" = <<-EOT
      [OUTPUT]
          Name cloudwatch_logs
          Match *
          region ${var.region}
          log_group_name /aws/eks/${var.cluster_name}/fluent-bit
          log_stream_prefix from-fluent-bit-
          auto_create_group true
    EOT
  }

  depends_on = [
    aws_cloudwatch_log_group.fluentbit_logs_with_prevent_destroy,
    aws_cloudwatch_log_group.fluentbit_logs_without_prevent_destroy
  ]
}

#########################################
# IAM Policy for Fargate Pod Logging
#########################################

data "aws_iam_policy_document" "fargate_logging" {
  count = var.enabled ? 1 : 0

  statement {
    sid    = "FargateLogWriteAccess"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy"
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/eks/${var.cluster_name}/fluent-bit:*"
    ]
  }

  statement {
    sid    = "AllowCreateLogGroup"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup"
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/eks/${var.cluster_name}/fluent-bit"
    ]
  }
}

resource "aws_iam_policy" "fargate_logging" {
  count = var.enabled ? 1 : 0

  name        = "${var.cluster_name}-fargate-logging"
  description = "IAM policy for Fargate pods to write logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fargate_logging[0].json

  tags = merge(
    {
      Name = "${var.cluster_name}-fargate-logging"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "fargate_logging" {
  count = var.enabled ? 1 : 0

  role       = var.fargate_pod_execution_role_name
  policy_arn = aws_iam_policy.fargate_logging[0].arn
}
