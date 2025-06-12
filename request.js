const fs = require("fs");
const path = require("path");
const {
    SubscriptionManager,
    SecretsManager,
    simulateScript,
    ResponseListener,
    ReturnType,
    decodeResult,
    FulfillmentCode,
} = require("@chainlink/functions-toolkit");
const functionsConsumerAbi = require("../../abi/functionsClient.json");
const ethers = require("ethers");
require("@chainlink/env-enc").config();

const consumerAddress = "0x0000000000000000000000000000000000000000"; // REPLACE this with your Functions consumer address
const subscriptionId = 3; // REPLACE this with your subscription ID

const makeRequestSepolia = async () => {
    // hardcoded for Ethereum Sepolia
    const routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
    const linkTokenAddress = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
    const donId = "fun-ethereum-sepolia-1";
    const explorerUrl = "https://sepolia.etherscan.io";
    const gatewayUrls = [
        "https://01.functions-gateway.testnet.chain.link/",
        "https://02.functions-gateway.testnet.chain.link/",
    ];

    // Initialize functions settings
    const source = fs
        .readFileSync(path.resolve(__dirname, "source.js"))
        .toString();
};