# ---------------------------------------------------------------------------
# EC2 Image Builder — Golden AMI pipeline for the web/app tier
#
# Flow: base Ubuntu AMI -> component (patch + harden + install) -> recipe
#       -> pipeline builds -> new versioned, patched AMI distributed to the region.
# The launch template's ami_id is then pointed at the latest output AMI, and the
# ASG performs a rolling instance refresh to replace running instances with zero
# downtime.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Component: the "what to do to the image" recipe step.
#   - Full OS patch (apt update/upgrade)
#   - Install nginx (web tier baseline)
#   - Basic hardening
#   - A validation step so a broken build fails the bake, not production
# ---------------------------------------------------------------------------
resource "aws_imagebuilder_component" "patch_and_setup" {
  name        = "${var.project_name}-patch-setup"
  platform    = "Linux"
  version     = var.component_version
  description = "Patch Ubuntu, install nginx, apply baseline hardening"

  data = yamlencode({
    name          = "patch-and-setup"
    description   = "Patch and configure the base image"
    schemaVersion = "1.0"
    phases = [
      {
        name = "build"
        steps = [
          {
            name      = "UpdateOS"
            action    = "ExecuteBash"
            onFailure = "Abort"
            inputs = {
              commands = [
                "set -euo pipefail",
                "export DEBIAN_FRONTEND=noninteractive",
                "apt-get update -y",
                "apt-get upgrade -y",
                "apt-get dist-upgrade -y",
                "apt-get autoremove -y"
              ]
            }
          },
          {
            name      = "InstallNginx"
            action    = "ExecuteBash"
            onFailure = "Abort"
            inputs = {
              commands = [
                "set -euo pipefail",
                "export DEBIAN_FRONTEND=noninteractive",
                "apt-get install -y nginx",
                "systemctl enable nginx"
              ]
            }
          },
          {
            name      = "Hardening"
            action    = "ExecuteBash"
            onFailure = "Abort"
            inputs = {
              commands = [
                "set -euo pipefail",
                # Ensure unattended-upgrades is present as an in-image backstop
                "export DEBIAN_FRONTEND=noninteractive",
                "apt-get install -y unattended-upgrades",
                # Example baseline: disable root SSH login if sshd config exists
                "if [ -f /etc/ssh/sshd_config ]; then sed -i 's/^#\\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config; fi"
              ]
            }
          }
        ]
      },
      {
        name = "validate"
        steps = [
          {
            name      = "VerifyNginx"
            action    = "ExecuteBash"
            onFailure = "Abort"
            inputs = {
              commands = [
                "set -euo pipefail",
                # Fail the bake if nginx isn't installed/enabled correctly
                "which nginx",
                "systemctl is-enabled nginx"
              ]
            }
          }
        ]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-patch-setup"
  }
}

# ---------------------------------------------------------------------------
# Recipe: base AMI + component(s) = the image definition.
# parent_image is the base Ubuntu AMI passed in (your existing data source).
# AWS-managed components add CloudWatch agent + an update step.
# ---------------------------------------------------------------------------
resource "aws_imagebuilder_image_recipe" "this" {
  name         = "${var.project_name}-recipe"
  version      = var.recipe_version
  parent_image = var.base_ami_id

  # Your custom patch/setup component
  component {
    component_arn = aws_imagebuilder_component.patch_and_setup.arn
  }

  # AWS-managed: applies latest OS updates at build time (belt-and-suspenders)
  component {
    component_arn = "arn:aws:imagebuilder:${var.region}:aws:component/update-linux/x.x.x"
  }

  block_device_mapping {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tags = {
    Name = "${var.project_name}-recipe"
  }
}

# ---------------------------------------------------------------------------
# Infrastructure config: where Image Builder spins up the temporary build
# instance. Uses an instance profile (defined below) and your private subnet.
# ---------------------------------------------------------------------------
resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                          = "${var.project_name}-infra-config"
  instance_profile_name         = aws_iam_instance_profile.image_builder.name
  instance_types                = ["t3.micro"]
  subnet_id                     = var.build_subnet_id
  security_group_ids            = [var.build_security_group_id]
  terminate_instance_on_failure = true

  tags = {
    Name = "${var.project_name}-infra-config"
  }
}

# ---------------------------------------------------------------------------
# Distribution config: where the finished AMI is published.
# ---------------------------------------------------------------------------
resource "aws_imagebuilder_distribution_configuration" "this" {
  name = "${var.project_name}-distribution"

  distribution {
    region = var.region

    ami_distribution_configuration {
      name = "${var.project_name}-golden-{{ imagebuilder:buildDate }}"

      ami_tags = {
        Name      = "${var.project_name}-golden-ami"
        BuildDate = "{{ imagebuilder:buildDate }}"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-distribution"
  }
}

# ---------------------------------------------------------------------------
# Pipeline: ties recipe + infra + distribution together and schedules builds.
# Schedule below = first day of every month at 03:00 UTC. Adjust cron as needed.
# You can also trigger manually from the console or CLI for emergency patches.
# ---------------------------------------------------------------------------
resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = "${var.project_name}-golden-ami-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn

  schedule {
    schedule_expression = var.build_schedule
    # Only build if there are pending OS updates vs the last build
    pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  }

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 90
  }

  tags = {
    Name = "${var.project_name}-golden-ami-pipeline"
  }
}

# ---------------------------------------------------------------------------
# IAM: the build instance needs an instance profile with the Image Builder
# and SSM managed policies (SSM is how Image Builder drives the build).
# ---------------------------------------------------------------------------
resource "aws_iam_role" "image_builder" {
  name = "${var.project_name}-image-builder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}-image-builder-role"
  }
}

resource "aws_iam_role_policy_attachment" "image_builder" {
  role       = aws_iam_role.image_builder.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.image_builder.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "image_builder" {
  name = "${var.project_name}-image-builder-profile"
  role = aws_iam_role.image_builder.name
}
