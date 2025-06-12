// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract InvoiceNFT is ERC721, FunctionsClient {
    error InvoiceNFT__NotFunctionsRouter();
    error InvoiceNFT__NotVerified();

    using FunctionsRequest for FunctionsRequest.Request;
    // Struct for invoice
    struct Invoice {
        uint256 amount; // Amount of the invoice
        uint256 dueDate; // Due date of the invoice
        address payer; // Address of the payer
        bool isPaid; // Whether the invoice is paid
    }

    // Mapping of invoice ID to invoice
    mapping(uint256 invoiceId => Invoice) public invoices; // Mapping of invoice ID to invoice

    // Event for when an invoice is minted
    event InvoiceMinted(
        uint256 indexed invoiceId,
        uint256 indexed amount,
        uint256 dueDate,
        address payer
    );

    // Pricefeed for USDC/USD
    AggregatorV3Interface internal immutable i_priceFeed;

    // Counter for invoice IDs
    uint256 private invoiceIdCounter;
    uint64 private s_subscriptionId;
    mapping(bytes32 => uint256) private requestToInvoiceId;

    modifier onlyFunctionsRouter() {
        if (msg.sender != address(i_router)) {
            revert InvoiceNFT__NotFunctionsRouter();
        }
        _;
    }

    modifier onlyVerified(uint256 invoiceId) {
        if (!invoices[invoiceId].isPaid) {
            revert InvoiceNFT__NotVerified();
        }
        _;
    }

    // Constructor
    constructor(
        address _priceFeed,
        address _functionsRouter
    ) ERC721("InvoiceNFT", "INV") FunctionsClient(_functionsRouter) {
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        invoiceIdCounter = 1;
    }

    function mintInvoice(
        uint256 amount,
        uint256 dueDate,
        address payer
    ) external {
        uint256 invoiceId = invoiceIdCounter;
        invoiceIdCounter++;
        invoices[invoiceId] = Invoice({
            amount: amount,
            dueDate: dueDate,
            payer: payer,
            isPaid: false
        });

        _safeMint(msg.sender, invoiceId);
        approve(payer, invoiceId);

        emit InvoiceMinted(invoiceId, amount, dueDate, payer);
    }

    function verifyInvoicePayment(uint256 invoiceId) external {
        Invoice memory invoice = invoices[invoiceId];

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            "const invoiceId = args[0];\nconst amount = args[1];\nconst payer = args[2];\n\nconst response = await Functions.makeHttpRequest({\n    url: 'https://api.chainlink.com/v1/payments/verify',\n    method: 'POST',\n    headers: {\n        'Content-Type': 'application/json'\n    },\n    data: {\n        invoiceId: invoiceId,\n        amount: amount,\n        payer: payer\n    }\n});\nreturn Functions.encodeBool(response.data.isPaid);"
        );
        string[] memory args = new string[](3);
        args[0] = Strings.toString(invoiceId);
        args[1] = Strings.toString(invoice.amount);
        args[2] = Strings.toHexString(uint256(uint160(invoice.payer)));
        req.setArgs(args);

        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            s_subscriptionId,
            3000000, // gas limit
            bytes32(0) // don hosted secrets slot id
        );

        requestToInvoiceId[requestId] = invoiceId;
    }

    function fulfillVerification(uint256 invoiceId, bool isPaid) external {
        invoices[invoiceId].isPaid = isPaid;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /*err*/
    ) internal override {
        uint256 invoiceId = requestToInvoiceId[requestId];
        bool isPaid = abi.decode(response, (bool));
        if (isPaid) {
            invoices[invoiceId].isPaid = true;
        }
    }
}
