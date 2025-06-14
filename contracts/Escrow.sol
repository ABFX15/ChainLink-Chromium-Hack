// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {InvoiceNFT} from "./InvoiceNFT.sol";

contract Escrow {
    InvoiceNFT public immutable i_invoiceNFT;

    constructor(address _invoiceNFT) {
        i_invoiceNFT = InvoiceNFT(_invoiceNFT);
    }

    function escrow(uint256 invoiceId) external {
        // TODO: Implement escrow
    }

}
