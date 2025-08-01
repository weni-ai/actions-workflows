# Actions Workflows

Central repository for GitHub Actions workflows and scripts.

# Public Actions Available

## build-lambda.yaml

This GitHub Action is designed to streamline the process of creating Docker images that will be used as base images for AWS Lambda functions, pushing these images to Amazon Elastic Container Registry(ECR) and automatically upgrading new versions.

The action aims to simplify the deployment pipeline by handling the complexities of image creation and management, allowing you to focus primarily on writing your Lambda function code.

### How It Works

1. **Triggering the Action**: When a tag with a format is pushed, this GitHub Action will be triggered.
2. **Docker Image Build**: The action uses Docker commands to build an image based on predefined Dockerfile and configuration settings.
3. **Push to AWS ECR**: After successful building, the image is pushed to your AWS ECR repository.
4. **Version Upgrade for Lambda**: Automatically updates infra-weni-lambda repository with the latest version of the Docker image.

### Usage

Include a workflow file in your repository. Below is an example configuration:

```yaml
name: Build lambda image and deploy(Push Tag)

on:
  push:
    tags:
      - '*.*.*-develop'
      - '*.*.*-staging'
      - '*.*.*'

jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      repository_name: ${{ steps.setup.outputs.repository_name }}
    steps:
      - name: Setup outputs
        id: setup
        run: |
          {
            echo "repository_name=${GITHUB_REPOSITORY#$GITHUB_REPOSITORY_OWNER/}"
          } | tee -a "${GITHUB_OUTPUT}"

          {
            echo "### Workflow Outputs"
            echo "| Variable        | Value           |"
            echo "| --------------- | --------------- |"
            echo "| repository_name | Repository name |"
          } | tee -a "${GITHUB_STEP_SUMMARY}"

  call-workflow:
    uses: weni-ai/actions-workflows/.github/workflows/build-lambda.yaml@main
    needs:
      - setup
    with:
      target_application: "${{ needs.setup.outputs.repository_name }}"
      image_tag_prefix: "${{ needs.setup.outputs.repository_name }}-"

    secrets: inherit

# vim: nu ts=2 fdm=indent et ft=yaml shiftwidth=2 softtabstop=2:
```

### Inputs

| Name               | Type        | Description                                                                                                                                                                       |
|--------------------|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `build_args` | String | Build arguments for docker build command. (e.g., `--build-arg foo=bar`) |
| `build_context` | String | Directory used to build context of image |
| `debug` | String | If `true`, enable debug messages |
| `default_environment` | String | When no string is used on tag, assume environment as this input. Defaults to `production` |
| `dockerfile` | String | Dockefile file location. Defaults to `Dockerfile`. |
| `image_arch` | List | A list with runner and a platform to build image. Default build arm64 and amd64 image.
| `image_latest` | Bool | If `"true"`, build latest image tag. Defaults `false`. |
| `image_repository` | String | Name of repository to push the image. Defaults to `lambda`. |
| `image_tag_latest_by_environment` | Bool | If `"true"`, latest image will be generated by environment. Defaults to `"false"` |
| `image_tag_prefix` | String | Prefix used on image. Defaults to `""` |
| `image_tag_prefix_onlatest` | String | If `"true"`, add prefix to latest image. Defaults to `"false"` |
| `image_tags` | List/CSV | Tags to be generated. Defaults to `"type=ref,event=tag"` |
| `target_application` | String | Target lambda to be modified in terraform repository. Can be a list with spaces. |
| `target_repository` | String | Repository to be updated when a image is generated. Defaults to `"weni-ai/infra-weni-lambda"` |
| `target_repository_branch` | String | `target_repository` to be modified. Defaults to `main`. |

### Secrets

| Name               | Description                                                    |
|--------------------|----------------------------------------------------------------|
| `DEVOPS_GITHUB_PERMANENT_TOKEN` | Token used to pull `input.target_repository` |
| `REGISTRY_ECR` | Registry URL. |
| `REGISTRY_TOKEN` | Registry token/password |
| `REGISTRY_USERNAME` | Registry username |

[modeline]: # ( vim: set fenc=utf-8 spell spl=en: )
