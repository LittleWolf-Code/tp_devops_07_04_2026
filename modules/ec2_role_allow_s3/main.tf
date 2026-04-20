# AWS Academy : on référence le LabRole et LabInstanceProfile existants
# (impossible de créer des rôles/policies IAM dans le Learner Lab)

data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

data "aws_iam_instance_profile" "lab_profile" {
  name = var.lab_instance_profile_name
}
