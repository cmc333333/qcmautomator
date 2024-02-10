# Quantified CM Automator

## Setting up a Codespace

Unfortunately, I've not found a way for Codespaces to use workload identity for authentication (as we can with GitHub Actions), so the deployment service account's key is available via a Codespace secret. Run the following when starting a new Codespace:

```
echo ${DEPLOYER_SERVICE_ACCOUNT_KEY} > ${CODESPACE_VSCODE_FOLDER}/creds.json
export GOOGLE_APPLICATION_CREDENTIALS=${CODESPACE_VSCODE_FOLDER}/creds.json
pushd ${CODESPACE_VSCODE_FOLDER}/terraform
terraform init -reconfigure
popd
```
