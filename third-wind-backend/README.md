# WindNet Backend: Deployment Guide

This folder contains the AWS CDK (Cloud Development Kit) code that will automatically build your serverless game infrastructure.

> **A NOTE FOR BEGINNERS:** If you have never used a terminal or AWS before, do not panic. Follow these steps exactly as written. If you see a weird error message, check the Troubleshooting section at the bottom.

## PHASE 1: Install Required Software
1. **Create an AWS Account:** Go to `aws.amazon.com` and create an account. WindNet's serverless architecture falls heavily under the AWS Free Tier.
2. **Install Node.js:** Go to `nodejs.org` and download the LTS installer for your OS.
3. **Install the AWS CLI:** Go to the official AWS website and download the standard AWS CLI installer for your OS.

## PHASE 2: Generate IAM Keys
Your local computer needs secure permission to build things inside your AWS account.
1. Log into the AWS Management Console.
2. Search for **IAM** and navigate to Users > **Create user**.
3. Name the user `windnet-admin` and click Next.
4. Select **Attach policies directly** and check **AdministratorAccess**. Create the user.
5. Click on `windnet-admin`, go to the **Security credentials** tab, and click **Create access key**.
6. Select **Command Line Interface (CLI)** and create the key.

⚠️ **STOP AND COPY THESE KEYS!** Keep the browser tab open. You cannot view the Secret Key again once closed.

## PHASE 3: Link Your Computer to AWS
1. Open a Terminal or Command Prompt.
2. Type `aws configure` and press Enter.
3. Paste the following when prompted:
   * **AWS Access Key ID:** (Paste from Phase 2)
   * **AWS Secret Access Key:** (Paste from Phase 2)
   * **Default region name:** `us-east-1` (or your closest region)
   * **Default output format:** `json`

## PHASE 4: Build the Cloud
1. Open your Terminal and navigate inside this `third-wind-backend` folder.
2. **Install dependencies:**
   ```bash
   npm install
   ```
3. **Bootstrap your environment:** (Only needs to be run once per AWS account)
   ```bash
   npx cdk bootstrap
   ```
4. **Deploy the infrastructure:**
   ```bash
   npx cdk deploy
   ```
   *(Type `y` when prompted). This usually takes 3 to 5 minutes.*

## PHASE 5: Harvest Your Credentials
When deployment finishes, the terminal will print a list of Outputs:
* `ThirdWindBackendStack.AppClientId = ...`
* `ThirdWindBackendStack.GraphQLAPIKey = ...`
* `ThirdWindBackendStack.GraphQLAPIURL = ...`
* `ThirdWindBackendStack.Region = us-east-1`

**COPY THOSE STRINGS!** You will paste these into the Godot `client-test` project to connect your game.

---

## 🛑 Troubleshooting

**1. "npm audit found vulnerabilities (yaml / Stack Overflow)"**
Ignore it. This is a known, harmless warning from Amazon's internal `aws-cdk-lib` build-time parser. It poses zero risk to your live game. Do not force an update or you will break the deployment.

**2. My code editor is covered in red error lines!**
If you see errors like `Cannot find module 'aws-cdk-lib'`, run `npm install` in your terminal. 

**3. "Environment failed bootstrapping: AWS::