# ---------------------------------------------------------------------------------------------------------------------
# IP ALLOWLIST FOR WAF 
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "ip_allow" {
  name               = "ip-allow"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.whiteListIP
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE ACL FOR WAF
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "WafWebAcl" {
  name  = "grafana-wafv2-web-acl"
  scope = "REGIONAL"

  default_action {
    block {
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAF_Common_Protections"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "ip-allowlist"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.ip_allow.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AllowlistedIP"
      sampled_requests_enabled   = true
    }
  }

depends_on = [
    aws_cloudwatch_log_group.WafWebAclLoggroup
  ]

}


# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH GROUP FOR LOGGING FOR WAF
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "WafWebAclLoggroup" {
  name              = "aws-waf-logs-grafana-wafv2-web-acl"
  retention_in_days = 1
}


# ---------------------------------------------------------------------------------------------------------------------
# ENABLE LOGGING
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_logging_configuration" "WafWebAclLogging" {
  log_destination_configs = [aws_cloudwatch_log_group.WafWebAclLoggroup.arn]
  resource_arn            = aws_wafv2_web_acl.WafWebAcl.arn
  depends_on = [
    aws_wafv2_web_acl.WafWebAcl,
    aws_cloudwatch_log_group.WafWebAclLoggroup
  ]
}


# ---------------------------------------------------------------------------------------------------------------------
# ASSOCIATE WAF TO ALB
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_wafv2_web_acl_association" "WafWebAclAssociation" {
  resource_arn = aws_lb.ecs_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.WafWebAcl.arn
  depends_on = [
    aws_wafv2_web_acl.WafWebAcl,
    aws_cloudwatch_log_group.WafWebAclLoggroup
  ]
}