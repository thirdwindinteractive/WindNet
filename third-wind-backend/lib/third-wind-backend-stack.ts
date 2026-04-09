import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as appsync from 'aws-cdk-lib/aws-appsync';
import * as path from 'path'; // Helper to find your schema file

export class ThirdWindBackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. AUTHENTICATION/USERBASE (Cognito) - This manages your Godot users
    const userPool = new cognito.UserPool(this, 'GodotUserPool', {
      selfSignUpEnabled: true, // Let players register themselves
      userVerification: { emailStyle: cognito.VerificationEmailStyle.CODE }, // Send them a 6-digit code
      signInCaseSensitive: false,
      signInAliases: { username: false, email: true } // Emails = Esernames, to allow both Emails and Esernames, set "username: true", this cannot be changed after deployment
    });

    const client = userPool.addClient('GodotAppClient', {
      authFlows: { userPassword: true } // Enables the flow we use in GDScript
    });

new cdk.CfnOutput(this, 'AppClientId', { value: client.userPoolClientId });

    // 2. DATABASE (DynamoDB) - This stores your Player Physics/Stats
    const playerTable = new dynamodb.Table(this, 'PlayerDataTable', {
      partitionKey: { name: 'playerId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST, // High performance, $0 cost if unused
      removalPolicy: cdk.RemovalPolicy.DESTROY // Use RETAIN when you go live so data isn't accidentally lost
    });

    // 3. THE API (AppSync)
    const api = new appsync.GraphqlApi(this, 'GodotApi', {
      name: 'ThirdWindGodotAPI',
      definition: appsync.Definition.fromSchema(
        appsync.SchemaFile.fromAsset(path.join(__dirname, '../graphql/schema.graphql'))
      ),
      authorizationConfig: {
        defaultAuthorization: {
          authorizationType: appsync.AuthorizationType.USER_POOL,
          userPoolConfig: {
            userPool: userPool // Only logged-in players can talk to the API
          },
        },
        additionalAuthorizationModes: [
          { authorizationType: appsync.AuthorizationType.API_KEY }
        ]
      },
      logConfig: { fieldLogLevel: appsync.FieldLogLevel.ALL }, // Crucial for debugging!
      xrayEnabled: true
    });

    // 4. THE BRAIN (AWS Lambda)
    const updateEngine = new lambda.Function(this, 'UpdateValidator', {
      runtime: lambda.Runtime.NODEJS_20_X, // Modern, fast runtime
      handler: 'index.handler',
      // This tells CDK to look for a folder named 'lambda' on your computer
      code: lambda.Code.fromAsset(path.join(__dirname, '../lambda')), 
      environment: {
        TABLE_NAME: playerTable.tableName,
      }
    });

    // 5. CONNECTING THE PIECES
    const dynamoDataSource = api.addDynamoDbDataSource('PlayerDataSource', playerTable);
    const lambdaDataSource = api.addLambdaDataSource('UpdateValidatorSource', updateEngine);

    // This handles Querying the data directly from the DB (Read-Only)
    dynamoDataSource.createResolver('GetPlayerResolver', {
      typeName: 'Query',
      fieldName: 'getPlayerState',
      requestMappingTemplate: appsync.MappingTemplate.dynamoDbGetItem('playerId', 'playerId'),
      responseMappingTemplate: appsync.MappingTemplate.dynamoDbResultItem()
    });

    // This forces the Mutation (Updates) to go through your Lambda "Referee" first
    lambdaDataSource.createResolver('UpdatePlayerResolver', {
      typeName: 'Mutation',
      fieldName: 'updatePlayerState',
    });

    // 6. OUTPUTS (The info you need for Godot)
    new cdk.CfnOutput(this, 'GraphQLAPIURL', { value: api.graphqlUrl });
    new cdk.CfnOutput(this, 'GraphQLAPIKey', { value: api.apiKey || 'None' });
    new cdk.CfnOutput(this, 'Region', { value: this.region });

    // 7. STORAGE (Amazon S3) - For DLC, textures, or any other large asset data
    const assetsBucket = new s3.Bucket(this, 'GodotAssetsBucket', {
      versioned: true, // Allows you to "roll back" if an update breaks a level
      encryption: s3.BucketEncryption.S3_MANAGED,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL, // Security first!
      removalPolicy: cdk.RemovalPolicy.RETAIN // Very important: Don't delete player files if the stack is deleted
    });

    // We output the bucket name so Godot knows where to upload/download from
    new cdk.CfnOutput(this, 'BucketName', { value: assetsBucket.bucketName });

    // Give the "Brain" permission to read/write to your "Storage Room"
    playerTable.grantReadWriteData(updateEngine);
  }
}
