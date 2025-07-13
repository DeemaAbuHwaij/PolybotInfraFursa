env           = "dev"
region        = "us-west-1"
ami_id        = "ami-014e30c8a36252ae5"
instance_type = "t3.medium"
key_name      = "DeemaKey"
vpc_cidr      = "10.0.0.0/16"
azs           = ["us-west-1a", "us-west-1b"]
desired_capacity = 3
min_size         = 2
max_size         = 3

# Required if your module expects public_subnets
public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

acm_cert_arn       = "arn:aws:acm:us-west-1:228281126655:certificate/fad14cdd-ebc5-4d46-9bf6-6fdaea33f5da"
s3_bucket_name     = "deema-dev-bucket"
sqs_queue_arn      = "arn:aws:sqs:us-west-1:228281126655:deema-polybot-chat-messages-dev"
dynamodb_table_arn = "arn:aws:dynamodb:us-west-1:228281126655:table/deema-PolybotPredictions-dev"


