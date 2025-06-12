import { ethers } from "ethers";
import "dotenv/config";

// Your contract address after deployment
const consumerAddress = "0x0000000000000000000000000000000000000000"; // REPLACE with your deployed contract
const subscriptionId = 3; // REPLACE with your subscription ID

const makeRequestSepolia = async () => {
    // Initialize the provider and wallet
    const provider = new ethers.providers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

    // Your invoice verification source code
    const source = `
        const invoiceId = args[0];
        const amount = args[1];
        const payer = args[2];

        // Make API call to verify payment
        const response = await Functions.makeHttpRequest({
            url: 'YOUR_PAYMENT_VERIFICATION_API',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            data: {
                invoiceId: invoiceId,
                amount: amount,
                payer: payer
            }
        });

        return Functions.encodeBool(response.data.isPaid);
    `;

    // Create the Functions request
    const functionsRequest = {
        source: source,
        args: ["1", "100", "0x123..."], // Example invoice data
        secrets: {}, // Add any API keys here
        subscriptionId: subscriptionId,
        gasLimit: 300000,
    };

    // Get the contract
    const contract = new ethers.Contract(consumerAddress, [
        "function verifyInvoicePayment(uint256 invoiceId) external"
    ], wallet);

    // Send the request
    const tx = await contract.verifyInvoicePayment(1);
    const receipt = await tx.wait();
    console.log("Transaction receipt:", receipt);
};

makeRequestSepolia().catch(console.error);