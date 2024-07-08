
    bucket         = "terraform-sftpgo-prod-state-do-not-delete"
    dynamodb_table = "terraform-sftpgo-prod-lock-do-not-delete"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true