terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "s3-bucket"
    key            = "global/s3/${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    # Replace this with your DynamoDB table name!
    dynamodb_table = "terraform-locks"
    encrypt        = true
    shared_credentials_file = "$HOME/.aws/credentials"
  }
}