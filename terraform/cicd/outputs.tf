# # Output pipeline information
# output "pipeline_name" {
#   description = "Name of the CodePipeline"
#   value       = aws_codepipeline.dofs_pipeline.name
# }

# output "pipeline_url" {
#   description = "URL to the CodePipeline console"
#   value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.dofs_pipeline.name}/view"
# }

# output "codecommit_clone_url" {
#   description = "CodeCommit repository clone URL"
#   value       = var.github_repo == "" ? aws_codecommit_repository.dofs_repo[0].clone_url_http : "Using GitHub repository"
# }
