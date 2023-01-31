# resources.tf
resource "aws_sns_topic" "sns_topic" {
    name = "tf-hire-test-cluster-PrometheusAlerts"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/ReceivePrometheusSNSNotifications.py"
  output_path = "${path.module}/lambda/ReceivePrometheusSNSNotifications.zip"
}

resource "aws_lambda_function" "ReceivePrometheusSNSNotifications" {
    filename         = "${path.module}/lambda/ReceivePrometheusSNSNotifications.zip"
    function_name    = "ReceivePrometheusSNSNotifications"
    role             = "${aws_iam_role.lambda_role.arn}"
    handler          = "ReceivePrometheusSNSNotifications.lambda_handler"
    source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
    runtime          = "python3.9"
}

resource "aws_iam_role" "lambda_role" {
    name = "LambdaRole"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_sqs_policy" {
    name = "AllowDynamodbPermissions"
    role = "${aws_iam_role.lambda_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "dynamodb:PutItem"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_role_logs_policy" {
    name = "LambdaRolePolicy"
    role = "${aws_iam_role.lambda_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_sns_topic_subscription" "invoke_with_sns" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ReceivePrometheusSNSNotifications.function_arn
}

resource "aws_lambda_permission" "allow_sns_invoke" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ReceivePrometheusSNSNotifications.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}


resource "aws_dynamodb_table" "dynamodb-table" {
  name           = "tf-EKS_cluster_monitoring"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "cluster_name"
  range_key      = "alert_name"

  attribute {
    name = "cluster_name"
    type = "S"
  }

  attribute {
    name = "alert_name"
    type = "S"
  }
 
}