terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


resource "aws_iam_policy" "NukeAccountCleanserPolicy" {
  name        = "NukeAccountCleanser"
  path        = var.IAMPath
  description = "Managed policy for nuke account cleaning"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "*"
        Effect   = "Allow"
        Resource = "*"
        Sid      = "WhitelistedServices"
      },
    ]
  })
}

//Controllo se la policy va splittata dal ruolo
/* resource "aws_iam_role" "NukeAccountCleanserRole" {
  name                 = var.NukeCleanserRoleName
  max_session_duration = 7200
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = aws_iam_role.NukeCodeBuildProjectRole.arn //Check se sintassi corretta
        }
      },
    ]
  })
  path                = var.IAMPath
  managed_policy_arns = aws_iam_policy.NukeAccountCleanserPolicy

  tags = {
    privileged  = "true",
    description = "PrivilegedReadWrite:auto-account-cleanser-role"
    owner       = var.Owner
  }
} */

resource "aws_iam_role" "NukeAccountCleanserRole" {
  name               = var.NukeCleanserRoleName
  description        = "Nuke Auto account cleanser role for Dev/Sandbox accounts"
  max_session_duration = 7200
  tags = {
    "privileged"   = "true"
    "description"  = "PrivilegedReadWrite:auto-account-cleanser-role"
    "owner"        = var.Owner
  }

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": [aws_iam_role.NukeCodeBuildProjectRole.arn]
      }
    }]
  })

  managed_policy_arns = [aws_iam_policy.NukeAccountCleanserPolicy.arn]

  path = var.IAMPath
}


resource "aws_iam_role" "EventBridgeNukeScheduleRole" {
  name = "EventBridgeNukeSchedule-${var.stack_name}"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "events.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
  })
}

resource "aws_iam_policy" "EventBridgeNukeStateMachineExecutionPolicy" {
  name = "EventBridgeNukeStateMachineExecutionPolicy"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "states:StartExecution",
          "Resource" : "${aws_sfn_state_machine.NukeStepFunction.arn}"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "EventBridgeNukeScheduleRoleAttachment" {
  role       = aws_iam_role.EventBridgeNukeScheduleRole.name
  policy_arn = aws_iam_policy.EventBridgeNukeStateMachineExecutionPolicy.arn
}

///////

resource "aws_iam_role" "NukeCodeBuildProjectRole" {
  name = "NukeCodeBuildProject-${var.stack_name}"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "codebuild.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    }
  )
}

resource "aws_iam_policy" "NukeCodeBuildLogsPolicy" {
  name        = "NukeCodeBuildLogsPolicy"
  description = "Policy for NukeCodeBuildLogs"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams",
            "logs:FilterLogEvents"
          ],
          "Resource" : [
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:AccountNuker-${var.stack_name}",
            "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:AccountNuker-${var.stack_name}:*"
          ]
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "NukeCodeBuildLogsPolicyAttachment" {
  role       = aws_iam_role.NukeCodeBuildProjectRole.name
  policy_arn = aws_iam_policy.NukeCodeBuildLogsPolicy.arn
}

resource "aws_iam_policy" "AssumeNukePolicy" {
  name        = "AssumeNukePolicy"
  description = "Policy for AssumeNuke"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sts:AssumeRole",
          "Resource" : "arn:aws:iam::*:role/${var.NukeCleanserRoleName}"
        }
      ]
    }
  )
}

resource "aws_iam_policy" "NukeListOUAccounts" {
  name        = "NukeListOUAccounts"
  description = "Policy for NukeListOUAccounts"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "organizations:ListAccountsForParent",
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_policy" "S3BucketReadOnly" {
  name        = "S3BucketReadOnly"
  description = "Policy for S3BucketReadOnly"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:Get*",
            "s3:List*"
          ],
          "Resource" : [
            "arn:aws:s3:::${aws_s3_bucket.NukeS3Bucket.id}",
            "arn:aws:s3:::${aws_s3_bucket.NukeS3Bucket.id}/*"
          ]
        }
      ]
    }
  )
}

resource "aws_iam_policy" "SNSPublishPolicy" {
  name        = "SNSPublishPolicy"
  description = "Policy for SNSPublishPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sns:ListTagsForResource",
        "sns:ListSubscriptionsByTopic",
        "sns:GetTopicAttributes",
        "sns:Publish"
      ]
      Resource = [
        aws_sns_topic.NukeEmailTopic.arn
      ]
    }]
  })
}

resource "aws_codebuild_project" "NukeCodeBuildProject" {
  name               = "AccountNuker-${var.stack_name}"
  description        = "Builds a container to run AWS-Nuke for all accounts within the specified account/regions"
  service_role       = aws_iam_role.NukeCodeBuildProjectRole.arn
  badge_enabled      = false
  build_timeout      = 120

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/docker:18.09.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_NukeDryRun"
      type  = "PLAINTEXT"
      value = var.AWSNukeDryRunFlag
    }

    environment_variable {
      name  = "AWS_NukeVersion"
      type  = "PLAINTEXT"
      value = var.AWSNukeVersion
    }

    environment_variable {
      name  = "Publish_TopicArn"
      type  = "PLAINTEXT"
      value = aws_sns_topic.NukeEmailTopic.arn
    }

    environment_variable {
      name  = "NukeS3Bucket"
      type  = "PLAINTEXT"
      value = aws_s3_bucket.NukeS3Bucket.id
    }

    environment_variable {
      name  = "NukeAssumeRoleArn"
      type  = "PLAINTEXT"
      value = aws_iam_role.NukeAccountCleanserRole.arn
    }

    environment_variable {
      name  = "NukeCodeBuildProjectName"
      type  = "PLAINTEXT"
      value = "AccountNuker-${var.stack_name}"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "AccountNuker-${var.stack_name}"
      status     = "ENABLED"
    }
  }

  source {
    buildspec = file("build_spec.yaml")
    type      = "NO_SOURCE"
  }

}

//aggiungi variabile stack name
resource "aws_cloudwatch_event_rule" "EventBridgeNukeSchedule" {
  name                = "EventBridgeNukeSchedule-${var.stack_name}"
  description         = "Scheduled Event for running AWS Nuke on the target accounts within the specified regions"
  schedule_expression = "cron(0 7 ? * * *)"
  is_enabled          = "true"
  role_arn            = aws_iam_role.EventBridgeNukeScheduleRole.arn
}

resource "aws_cloudwatch_event_target" "EventBridgeNukeScheduleTarget" {
  rule      = aws_cloudwatch_event_rule.EventBridgeNukeSchedule.name
  target_id = aws_sfn_state_machine.NukeStepFunction.name
  arn       = aws_sfn_state_machine.NukeStepFunction.arn
  role_arn  = aws_iam_role.EventBridgeNukeScheduleRole.arn

  input = jsonencode(
    {
      "InputPayLoad" : {
        "nuke_dry_run" : "${var.AWSNukeDryRunFlag}",
        "nuke_version" : "${var.AWSNukeVersion}",
        "region_list" : [
          "us-west-1",
          "us-east-1"
        ]
      }
  })
}

resource "aws_s3_bucket" "NukeS3Bucket" {
  bucket = join("-", [
    var.BucketName,
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name
    ]) 

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    "DoNotNuke" = "True"
    "owner"     = var.Owner
  }
}

output "NukeS3Bucket" {
  value = "${aws_s3_bucket.NukeS3Bucket.id}"
}

resource "aws_s3_bucket_public_access_block" "public_Access" {
    bucket = aws_s3_bucket.NukeS3Bucket.id
    block_public_acls       = true
    ignore_public_acls      = true
    block_public_policy     = true
    restrict_public_buckets = true
  }

resource "aws_s3_bucket_policy" "NukeS3BucketPolicy" {
  bucket = aws_s3_bucket.NukeS3Bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "ForceSSLOnlyAccess",
        "Effect" : "Deny",
        "Principal" : "*",
        "Action" : "s3:*",
        "Resource" : [
          "${aws_s3_bucket.NukeS3Bucket.arn}",
          "${aws_s3_bucket.NukeS3Bucket.arn}/*"
        ],
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic" "NukeEmailTopic" {
  display_name      = "NukeTopic"
  fifo_topic        = false
  kms_master_key_id = "alias/aws/sns"
  name              = var.NukeTopicName

  tags = {
    "DoNotNuke" = "True"
    "owner"     = var.Owner
  }
}

resource "aws_sns_topic_subscription" "NukeEmailTopicSubscription" {
  topic_arn = aws_sns_topic.NukeEmailTopic.arn
  protocol  = "email"
  endpoint  = "fabrocco@amazon.it" # Provide your valid email address for receiving notifications
}

resource "aws_iam_role" "NukeStepFunctionRole" {
  name = "nuke-account-cleanser-codebuild-state-machine-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : [
            "states.${data.aws_region.current.name}.amazonaws.com"
          ]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  path = "/"

  tags = {
    "Name" : "NukeStepFunctionRole"
  }
}

resource "aws_iam_policy" "NukeStepFunctionRolePolicy" {
  name = "nuke-account-cleanser-codebuild-state-machine-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:StartBuildBatch",
          "codebuild:StopBuildBatch",
          "codebuild:RetryBuild",
          "codebuild:RetryBuildBatch",
          "codebuild:BatchGet*",
          "codebuild:GetResourcePolicy",
          "codebuild:DescribeTestCases",
          "codebuild:DescribeCodeCoverages",
          "codebuild:List*"
        ],
        "Resource" : [
          aws_codebuild_project.NukeCodeBuildProject.arn
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "events:PutTargets",
          "events:PutRule",
          "events:DescribeRule"
        ],
        "Resource" : "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventForCodeBuildStartBuildRule"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "sns:Publish"
        ],
        "Resource" : [
          aws_sns_topic.NukeEmailTopic.arn
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "states:DescribeStateMachine",
          "states:ListExecutions",
          "states:StartExecution",
          "states:StopExecution",
          "states:DescribeExecution"
        ],
        "Resource" : "arn:aws:states:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stateMachine:nuke-account-cleanser-codebuild-state-machine"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "NukeStepFunctionRolePolicyAttachment" {
  role       = aws_iam_role.NukeStepFunctionRole.name
  policy_arn = aws_iam_policy.NukeStepFunctionRolePolicy.arn
}

resource "aws_sfn_state_machine" "NukeStepFunction" {
  name     = "nuke-account-cleanser-codebuild-state-machine"
  role_arn = aws_iam_role.NukeStepFunctionRole.arn

  definition = jsonencode(
    {
      "Comment" : "AWS Nuke Account Cleanser for multi-region single account clean up using SFN Map state parallel invocation of CodeBuild project.",
      "StartAt" : "StartNukeCodeBuildForEachRegion",
      "States" : {
        "StartNukeCodeBuildForEachRegion" : {
          "Type" : "Map",
          "ItemsPath" : "$.InputPayLoad.region_list",
          "Parameters" : {
            "region_id.$" : "$$.Map.Item.Value",
            "nuke_dry_run.$" : "$.InputPayLoad.nuke_dry_run",
            "nuke_version.$" : "$.InputPayLoad.nuke_version"
          },
          "Next" : "Clean Output and Notify",
          "MaxConcurrency" : 0,
          "Iterator" : {
            "StartAt" : "Trigger Nuke CodeBuild Job",
            "States" : {
              "Trigger Nuke CodeBuild Job" : {
                "Type" : "Task",
                "Resource" : "arn:aws:states:::codebuild:startBuild.sync",
                "Parameters" : {
                  "ProjectName" : "${aws_codebuild_project.NukeCodeBuildProject.arn}",
                  "EnvironmentVariablesOverride" : [
                    {
                      "Name" : "NukeTargetRegion",
                      "Type" : "PLAINTEXT",
                      "Value.$" : "$.region_id"
                    },
                    {
                      "Name" : "AWS_NukeDryRun",
                      "Type" : "PLAINTEXT",
                      "Value.$" : "$.nuke_dry_run"
                    },
                    {
                      "Name" : "AWS_NukeVersion",
                      "Type" : "PLAINTEXT",
                      "Value.$" : "$.nuke_version"
                    }
                  ]
                },
                "Next" : "Check Nuke CodeBuild Job Status",
                "ResultSelector" : {
                  "NukeBuildOutput.$" : "$.Build"
                },
                "ResultPath" : "$.AccountCleanserRegionOutput",
                "Retry" : [
                  {
                    "ErrorEquals" : [
                      "States.TaskFailed"
                    ],
                    "BackoffRate" : 1,
                    "IntervalSeconds" : 1,
                    "MaxAttempts" : 1
                  }
                ],
                "Catch" : [
                   {
                    "ErrorEquals" : [
                      "States.ALL"
                    ],
                    "Next" : "Nuke Failed",
                    "ResultPath" : "$.AccountCleanserRegionOutput"
                  }
                ]
              },
              "Check Nuke CodeBuild Job Status" : {
                "Type" : "Choice",
                "Choices" : [
                  {
                    "Variable" : "$.AccountCleanserRegionOutput.NukeBuildOutput.BuildStatus",
                    "StringEquals" : "SUCCEEDED",
                    "Next" : "Nuke Success"
                  },
                  {
                    "Variable" : "$.AccountCleanserRegionOutput.NukeBuildOutput.BuildStatus",
                    "StringEquals" : "FAILED",
                    "Next" : "Nuke Failed"
                  }
                ],
                "Default" : "Nuke Success"
              },
              "Nuke Success" : {
                "Type" : "Pass",
                "Parameters" : {
                  "Status" : "Succeeded",
                  "Region.$" : "$.region_id",
                  "CodeBuild Status.$" : "$.AccountCleanserRegionOutput.NukeBuildOutput.BuildStatus"
                },
                "ResultPath" : "$.result",
                "End" : true
              },
              "Nuke Failed" : {
                "Type" : "Pass",
                "Parameters" : {
                  "Status" : "Failed",
                  "Region.$" : "$.region_id",
                  "CodeBuild Status.$" : "States.Format('Nuke Account Cleanser failed with error {}. Check CodeBuild execution for input region {} to investigate', $.AccountCleanserRegionOutput.Error, $.region_id)"
                },
                "ResultPath" : "$.result",
                "End" : true
              }
            }
          },
          "ResultSelector" : {
            "filteredResult.$" : "$..result"
          },
          "ResultPath" : "$.NukeFinalMapAllRegionsOutput"
        },
        "Clean Output and Notify" : {
          "Type" : "Task",
          "Resource" : "arn:aws:states:::sns:publish",
          "Parameters" : {
            "Subject" : "State Machine for Nuke Account Cleanser completed",
            "Message.$" : "States.Format('Nuke Account Cleanser completed for input payload: \n {}. \n ----------------------------------------- \n Check the summmary of execution below: \n {}', $.InputPayLoad, $.NukeFinalMapAllRegionsOutput.filteredResult)",
            "TopicArn" : "${aws_sns_topic.NukeEmailTopic.arn}"
          },
          "End" : true
        }
      }
    }
  )
  tags = {
    DoNotNuke = "True"
    "owner"   = var.Owner
  }
}

output "NukeTopicArn" {
  description = "Arn of SNS Topic used for notifying nuke results in email"
  value       = aws_sns_topic.NukeEmailTopic.arn
}

output "NukeS3BucketValue" {
  description = "S3 bucket created with the random generated name"
  value       = aws_s3_bucket.NukeS3Bucket.id
}

