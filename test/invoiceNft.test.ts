import { expect } from "chai";
import { viem } from "hardhat";
import { parseEther } from "viem";

describe("InvoiceNFT", function () {
    const FUNCTIONS_ROUTER = "0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C";
    const USDC_USD_FEED = "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E";

    let invoiceNFT: any;
    let owner: any, payer: any;

    before(async function () {
        [owner, payer] = await viem.getWalletClients();

        invoiceNFT = await viem.deployContract("InvoiceNFT", [
            USDC_USD_FEED,
            FUNCTIONS_ROUTER
        ]);
    });

    it("Should mint an invoice NFT", async function () {
        const dueDate = BigInt(Math.floor(Date.now() / 1000)) + 86400n;

        await invoiceNFT.write.mintInvoice([
            parseEther("1000"),
            dueDate,
            payer.account.address
        ]);

        const ownerOf = await invoiceNFT.read.ownerOf([1n]);
        expect(ownerOf.toLowerCase()).to.equal(owner.account.address.toLowerCase());
    });
});