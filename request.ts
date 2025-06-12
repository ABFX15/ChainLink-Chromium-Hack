import fs from "fs";
import path from "path";
import { ethers } from "ethers";
import "dotenv/config";

// Import your contract ABI
const functionsConsumerAbi = require("../../abi/functionsClient.json");

const consumerAddress = "0x0000000000000000000000000000000000000000"; // replace with functions consumer address
const subscriptionId = 3 // replace with your subscription id

const makeRequestSepolia = async () => {
    const routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
    const linkTokenAddress = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
    const donId = "fun-ethereum-sepolia-1";
    const explorerUrl = "https://sepolia.etherscan.io";
    const gatewayUrls = [
        "https://01.functions-gateway.testnet.chain.link/",
        "https://02.functions-gateway.testnet.chain.link/",
    ];
}