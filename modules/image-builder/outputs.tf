output "pipeline_arn" {
  description = "ARN of the Image Builder pipeline (use to trigger manual builds)"
  value       = aws_imagebuilder_image_pipeline.this.arn
}

output "component_arn" {
  description = "ARN of the patch/setup component"
  value       = aws_imagebuilder_component.patch_and_setup.arn
}

output "recipe_arn" {
  description = "ARN of the image recipe"
  value       = aws_imagebuilder_image_recipe.this.arn
}

# Note: the *output AMI ID* is not known at apply time — it's produced when the
# pipeline runs. To consume the latest golden AMI in your launch template, look
# it up with a data source filtering on the AMI tags (see usage notes).
