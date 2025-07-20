
# Outputs
output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = aws_codepipeline.dofs_pipeline.name
}

output "pipeline_url" {
  description = "URL to the CodePipeline console"
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.dofs_pipeline.name}/view"
}

output "codebuild_project" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.terraform_deploy.name
}
