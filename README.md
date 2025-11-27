# Actions Workflows

Central repository for GitHub Actions workflows and scripts.

# Public Actions Available

## .github/workflows/reusable-workflow.yaml

This GitHub Action is designed to streamline the process of creating Docker images that will be used as base images for AWS Lambda functions and Kubernetes, pushing these images to Amazon Elastic Container Registry(ECR) and automatically upgrading new versions.

The action aims to simplify the deployment pipeline by handling the complexities of image creation and management, allowing you to focus primarily on writing your code.

### How It Works

1. **Triggering the Action**: When a tag with a format is pushed, this GitHub Action will be triggered.
2. **Docker Image Build**: The action uses Docker commands to build an image based on predefined Dockerfile and configuration settings.
3. **Push to Registry**: After successful building, the image is pushed to your AWS ECR repository or another registry.
4. **Version Upgrade for Deploy**: Automatically updates `infra-weni-*` or another `kubernetes-manifests*` repository with the latest version of the Docker image.

### Usage

Include a workflow file in your repository. Below is an example configuration for `infra-weni-lambda` or `kubernetes-manifests*`:

#### infra-weni-lambda

```yaml
name: Build, push and deploy

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
    uses: weni-ai/actions-workflows/.github/workflows/reusable-workflow.yaml@main
    needs:
      - setup
    with:
      deploy_type: 'terraform'
      image_repository: 'lambda'
      target_repository: 'weni-ai/infra-weni-lambda'
      target_application: "${{ needs.setup.outputs.repository_name }}"
      image_tag_prefix: "${{ needs.setup.outputs.repository_name }}-"
    secrets: inherit

# vim: nu ts=2 fdm=indent et ft=yaml shiftwidth=2 softtabstop=2:
```

#### kubernetes-manifests-*

```yaml
name: Build, push and deploy

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
    uses: weni-ai/actions-workflows/.github/workflows/reusable-workflow.yaml@main
    needs:
      - setup
    with:
      deploy_type: 'kubernetes'
      target_application: "${{ needs.setup.outputs.repository_name }}"
      image_repository: "${{ needs.setup.outputs.repository_name }}"
      target_repository: 'weni-ai/kubernetes-manifests'
    secrets: inherit

# vim: nu ts=2 fdm=indent et ft=yaml shiftwidth=2 softtabstop=2:
```

### Inputs

| Name               | Type        | Description                                                                                                                                                                       |
|--------------------|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `aws_ssm_name` | String | Optional. Parameter name to retrieve VCS token |
| `aws_region` | String | Default to `us-east-1` |
| `build_args` | String | Build arguments for docker build command. (e.g., `--build-arg foo=bar`) |
| `build_context` | String | Directory used to build context of image |
| `debug` | String | If `true`, enable debug messages |
| `default_environment` | String | When no string is used on tag, assume environment as this input. Defaults to `production` |
| `dockerfile` | String | Dockefile file location. Defaults to `Dockerfile`. |
| `deploy_type` | String | Default o `kubernetes`. Deploy type who need to be upgrade the image version. |
| `image_arch` | List | A list with runner and a platform to build image. Default build arm64 and amd64 image.
| `image_latest` | Bool | If `"true"`, build latest image tag. Defaults `false`. |
| `image_repository` | String | Name of repository to push the image. Defaults to `lambda`. |
| `image_tag_latest_by_environment` | Bool | If `"true"`, latest image will be generated by environment. Defaults to `"false"` |
| `image_tag_prefix` | String | Prefix used on image. Defaults to `""` |
| `image_tag_prefix_onlatest` | String | If `"true"`, add prefix to latest image. Defaults to `"false"` |
| `image_tags` | List/CSV | Tags to be generated. Defaults to `"type=ref,event=tag"` |
| `target_application` | String | Target lambda to be modified in terraform repository. Can be a list with spaces. |
| `target_application_directory_prefix` | String | Prefix used in target application directory. Use in applications with subdirectory. |
| `target_repository` | String | Repository to be updated when a image is generated. |
| `target_repository_branch` | String | `target_repository` to be modified. Defaults to `main`. |
| `target_patch_file` | String | File to be updated the application version. Defaults to `deployment.json` for kubernetes. |
| `kludge_webapp_secret_enable` | Boolean | Enable get secrets from webapp-secret repository. Defaults to `false`. |

### Secrets

| Name               | Description                                                           |
|--------------------|-----------------------------------------------------------------------|
| `DEVOPS_GITHUB_PERMANENT_TOKEN` | Optional. Token used to pull `input.target_repository`   |
| `ROLE_ARN` | Preferred. Assumed role used to AWS. Used for push to ECR and something more. |
| `REGISTRY_ECR` | Registry URL. |
| `REGISTRY_TOKEN` | Optional. Registry token/password |
| `REGISTRY_USERNAME` | Optional. Registry username |

## weni-ai/actions-workflows/secret-output

This gitHub action encrypts or decrypts input data using a provided secret, allowing secure transmission between jobs. It accepts an operation type (encode/decode), input data, and an optional secret for encryption/decryption. The encrypted result is returned as the output.

This is to solve the problem with github erase output between jobs.

### How It Works

1. **Obfuscate a secret output**: Use gpg to create a obfuscated output how cannot read in the logs.
2. **Pass encrypted output as job output**: Use the obfuscated output as a job output.
3. **Decrypt job output and use in another job**: Use the obfustated output after decrypt.

### Usage

Include a workflow file in your repository. You can use a secret value in input.secret, but if you like to use secretless, you can remove this option(remember to cleanup in the end).

Below is an example:

```yaml
on: [push]

jobs:
  setup:
    runs-on: ubuntu-latest
    name: A job to test action to encode secret output
    outputs:
      out: ${{ steps.encode.outputs.out }}
    steps:
      - name: Cache secret
        uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.cache_secret/.token
          key: token-secret-output

      - name: Encode secret
        uses: weni-ai/actions-workflows/secret-output@main
        id: encode
        with:
          in: "A LONG DEPLOY SECRETKEY GENERATE IN A STEP"

  another_job:
    runs-on: ubuntu-latest
    name: Another job how use a secret
    needs:
      - setup
    steps:
      - name: Cache secret
        uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.cache_secret/.token
          key: token-secret-output

      - name: Decode
        uses: weni-ai/actions-workflows/secret-output@main
        id: decode
        with:
          op: decode
          in: ${{ needs.setup.outputs.out }}"

      - name: IF Output decode is equal
        run: |
          if [ "${{ steps.decode.outputs.out }}" != "AAAAAAAA" ] ; then
            echo "Diff in output"
            exit 1
          fi

  cleanup:
    runs-on: ubuntu-latest
    needs:
      - another_job
    steps:
      - name: Cache secret
        uses: actions/cache@v4
        with:
          path: ${{ github.workspace }}/.cache_secret/.token
          key: token-secret-output
      - name: Cleanup Step
        if: always()
        uses: weni-ai/actions-workflows/secret-output@main
        id: decode

# vim: nu ts=2 fdm=indent et ft=yaml shiftwidth=2 softtabstop=2:
```

### Inputs

| Name               | Type        | Description                                                                                                                                                                       |
|--------------------|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `op` | String | Type of operation, can be `cleanup`, `decode`, `toml-decode` or `encode`. Defaults to `encode`. |
| `in` | String | Input data. |
| `secret` | String | Secret to encrypt/decrypt data. Optional if cache is used. |
| `log_level` | String | Log level used in action, default to INFO. |

[modeline]: # ( vim: set fenc=utf-8 spell spl=en: )
