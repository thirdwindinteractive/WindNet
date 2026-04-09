# Contributing to WindNet

First off, thank you for considering contributing to WindNet! Third Wind Interactive relies on community support to keep tools like this free, open-source, and constantly improving. 

Since WindNet is managed by a solo developer, these guidelines help keep the process clean and efficient.

## Ground Rules

To ensure your Pull Request gets approved, please follow these rules:

* **Keep it scoped:** A Pull Request should do *one* thing. Please do not submit a massive PR that completely rewrites the core architecture and adds 4 different features at once. Small, focused updates are much easier to review and approve.
* **No Twitch-Shooter Logic:** WindNet is specifically engineered as a low-cost, serverless GraphQL meta-backend (for RPGs, turn-based games, lobbies, etc.). PRs attempting to brute-force high-frequency UDP server logic into this AWS CDK stack will be rejected.
* **Test your code:** Before submitting a PR, please ensure your changes actually deploy successfully via `npx cdk deploy` and do not break the existing Godot `client-test`.

## Found a Bug?
If you don't know how to fix a bug but want to report it, please open an **Issue** on the GitHub page or drop it in our Discord server. Please include the exact error message and the steps to reproduce it.

Thanks for helping make game development more accessible!
