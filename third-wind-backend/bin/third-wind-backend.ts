import * as cdk from 'aws-cdk-lib';
import { ThirdWindBackendStack } from '../lib/third-wind-backend-stack';

const app = new cdk.App();
new ThirdWindBackendStack(app, 'ThirdWindBackendStack', {
  // This tells the CDK to automatically use the AWS Account and Region 
  // of whoever is running the 'cdk deploy' command in their terminal.
  env: { 
    account: process.env.CDK_DEFAULT_ACCOUNT, 
    region: process.env.CDK_DEFAULT_REGION 
  },
});
