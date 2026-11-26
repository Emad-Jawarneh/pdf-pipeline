resource "aws_sqs_queue" "processing_dead_letter" {
  name                      = "pdf-pipeline-local-processing-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "processing" {
  name                       = "pdf-pipeline-local-processing"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.processing_dead_letter.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "processing_dead_letter" {
  queue_url = aws_sqs_queue.processing_dead_letter.url

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.processing.arn]
  })
}

resource "aws_cloudwatch_event_rule" "original_uploaded" {
  name        = "pdf-pipeline-local-original-uploaded"
  description = "Routes object creation events from the original PDF bucket."

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.originals.bucket] }
    }
  })
}

resource "aws_sqs_queue_policy" "processing" {
  queue_url = aws_sqs_queue.processing.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowOriginalUploadRule"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.processing.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.original_uploaded.arn }
      }
    }]
  })
}

resource "aws_cloudwatch_event_target" "processing" {
  rule      = aws_cloudwatch_event_rule.original_uploaded.name
  target_id = "processing-queue"
  arn       = aws_sqs_queue.processing.arn

  depends_on = [aws_sqs_queue_policy.processing]
}

output "processing_queue_url" {
  description = "SQS queue for document processing jobs."
  value       = aws_sqs_queue.processing.url
}

output "processing_dead_letter_queue_url" {
  description = "SQS queue for jobs that exhaust processing attempts."
  value       = aws_sqs_queue.processing_dead_letter.url
}
