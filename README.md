# WindNet: Serverless Godot Backend

WindNet is an open-source, infrastructure-as-code toolkit designed to get a serverless Godot backend up and running on AWS in minutes. It handles the heavy lifting of cloud architecture so you can focus on building your game.

It is built completely on AWS Free-Tier eligible and Serverless technologies ($0 idle costs) including:
* **Amazon Cognito:** User Authentication & JWTs
* **AWS AppSync:** GraphQL API & Real-time WebSockets
* **AWS Lambda:** Serverless Compute Logic
* **Amazon DynamoDB:** NoSQL Database Persistence

## 📂 Repository Structure & Where to Start
Please tackle these folders in order. You must build your cloud before the Godot client can connect to it!

1. **`/third-wind-backend`**
   Start here. This contains the AWS CDK (Cloud Development Kit) source code that deploys your serverless infrastructure to the cloud. Open the README inside for your step-by-step terminal deployment guide.

2. **`/client-test`**
   Once your backend is live, open this Godot project. It contains fully functional working examples of User Authentication (Sign-up/Login/Tokens) and a real-time Multiplayer Synchronization test connected to your new AWS AppSync endpoints.

3. **`/guide-scripts`**
   These are advanced GDScript blueprints outlining different ways to implement AppSync WebSockets (Fixed-Tick vs. Event-Driven). They are educational references to help you design the networking logic for your specific game genre.

## 💬 Community & Support
If you need help troubleshooting an AWS deployment or want to discuss Godot networking, join the community:
* **Discord:** [Join the Third Wind Interactive Server](https://discord.gg/qG4qJbW5UR)

## ❤️ Support the Project
WindNet is 100% free and open-source. If this toolkit saved you weeks of backend engineering and you'd like to support continued development, consider leaving a tip!
* **Donate:** [thirdwindinteractive.com/donate](https://www.thirdwindinteractive.com/donate)