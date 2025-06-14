// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PriceOracle} from "./PriceOracle.sol";

/// @title InvoiceNFT
/// @author Your Name
/// @notice NFT-based invoice system with Chainlink integration for payment verification, auditor selection, and automation
/// @dev Inherits from ERC721, FunctionsClient, VRFConsumerBaseV2, and AutomationCompatibleInterface
/// @custom:security-contact your-email@example.com
contract InvoiceNFT is
    ERC721,
    FunctionsClient,
    VRFConsumerBaseV2,
    AutomationCompatibleInterface,
    Ownable,
    ReentrancyGuard
{
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error InvoiceNFT__NotFunctionsRouter();
    error InvoiceNFT__NotVerified();
    error InvoiceNFT__NotOwner();
    error InvoiceNFT__InvalidAmount();
    error InvoiceNFT__NotListed();
    error InvoiceNFT__InvalidPriceFeed();
    error InvoiceNFT__InvalidFunctionsRouter();
    error InvoiceNFT__InvalidVRFCoordinator();
    error InvoiceNFT__NotPayer();
    error InvoiceNFT__StalePriceFeed();
    error InvoiceNFT__InvalidDueDate();

    using FunctionsRequest for FunctionsRequest.Request;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Represents an invoice in the system
    /// @param amount The amount of the invoice in USDC
    /// @param dueDate The due date of the invoice (Unix timestamp)
    /// @param payer The address of the entity responsible for payment
    /// @param isPaid Whether the invoice has been paid
    /// @param isListed Whether the invoice is listed for sale
    struct Invoice {
        uint256 amount;
        uint256 dueDate;
        address payer;
        bool isPaid;
        bool isListed;
    }

    /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 invoiceId => Invoice) public invoices; // Mapping of invoice ID to invoice
    mapping(bytes32 => uint256) private requestToInvoiceId;

    AggregatorV3Interface internal immutable i_priceFeed; // Pricefeed for USDC/USD
    PriceOracle internal immutable i_priceOracle; // PriceOracle for USDC/USD conversions

    uint256 private invoiceIdCounter; // Counter for invoice IDs
    uint64 private s_subscriptionId; // Chainlink subscription ID

    uint256 private constant FEE_PERCENTAGE = 50; // 0.5% fee
    uint256 private constant PRECISION = 10000; // 100%

    // Add VRF related state variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Add USDC interface
    IERC20 public immutable USDC;

    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a new invoice NFT is minted
    /// @param invoiceId The ID of the minted invoice
    /// @param amount The amount of the invoice
    /// @param dueDate The due date of the invoice
    /// @param payer The address of the payer
    event InvoiceMinted(
        uint256 indexed invoiceId,
        uint256 indexed amount,
        uint256 dueDate,
        address payer
    );

    /// @notice Emitted when an invoice is listed for sale
    /// @param invoiceId The ID of the listed invoice
    /// @param amount The amount of the invoice
    event InvoiceListed(uint256 indexed invoiceId, uint256 indexed amount);

    /// @notice Emitted when an invoice is canceled
    /// @param invoiceId The ID of the canceled invoice
    event InvoiceCanceled(uint256 indexed invoiceId);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
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

    /// @notice Initializes the contract with required addresses and parameters
    /// @param _priceFeed Address of the Chainlink price feed
    /// @param _functionsRouter Address of the Chainlink Functions router
    /// @param _vrfCoordinator Address of the VRF coordinator
    /// @param _gasLane The gas lane to use for VRF requests
    /// @param _subscriptionId The Chainlink subscription ID
    /// @param _callbackGasLimit Gas limit for the callback
    /// @param _usdc Address of the USDC token
    constructor(
        address _priceFeed,
        address _functionsRouter,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit,
        address _usdc
    )
        ERC721("InvoiceNFT", "INV")
        FunctionsClient(_functionsRouter)
        VRFConsumerBaseV2(_vrfCoordinator)
        Ownable(msg.sender)
    {
        if (_priceFeed == address(0)) {
            revert InvoiceNFT__InvalidPriceFeed();
        }
        if (_functionsRouter == address(0)) {
            revert InvoiceNFT__InvalidFunctionsRouter();
        }
        if (_vrfCoordinator == address(0)) {
            revert InvoiceNFT__InvalidVRFCoordinator();
        }
        i_priceFeed = AggregatorV3Interface(_priceFeed);
        invoiceIdCounter = 1;
        i_priceOracle = new PriceOracle(_priceFeed);
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        USDC = IERC20(_usdc);
    }

    /*//////////////////////////////////////////////////////////////
                               EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a new invoice NFT
    /// @param amount The amount of the invoice in USDC
    /// @param dueDate The due date of the invoice (Unix timestamp)
    /// @param payer The address of the entity responsible for payment
    /// @dev Mints an NFT and approves the payer to transfer it
    /// @dev Emits InvoiceMinted event
    function mintInvoice(
        uint256 amount,
        uint256 dueDate,
        address payer
    ) external nonReentrant {
        uint256 invoiceId = invoiceIdCounter;
        invoiceIdCounter++;
        if (amount == 0) {
            revert InvoiceNFT__InvalidAmount();
        }
        if (dueDate <= block.timestamp) {
            revert InvoiceNFT__InvalidDueDate();
        }
        invoices[invoiceId] = Invoice({
            amount: amount,
            dueDate: dueDate,
            payer: payer,
            isPaid: false,
            isListed: false
        });

        _safeMint(msg.sender, invoiceId);
        approve(payer, invoiceId);

        emit InvoiceMinted(invoiceId, amount, dueDate, payer);
    }

    /// @notice Initiates payment verification for an invoice
    /// @param invoiceId The ID of the invoice to verify
    /// @dev Uses Chainlink Functions to verify payment status
    /// @dev Stores request ID for callback handling
    function verifyInvoicePayment(uint256 invoiceId) external nonReentrant {
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

    /// @notice Updates invoice payment status
    /// @param invoiceId The ID of the invoice to update
    /// @param isPaid Whether the invoice has been paid
    /// @dev Can only be called by the Functions Router
    /// @dev Updates the isPaid status of the invoice
    function fulfillVerification(
        uint256 invoiceId,
        bool isPaid
    ) external onlyFunctionsRouter nonReentrant {
        invoices[invoiceId].isPaid = isPaid;
    }

    /*//////////////////////////////////////////////////////////////
                            AUTOMATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Checks if any invoices need automated attention
    /// @param checkData Additional data for the check (unused)
    /// @return upkeepNeeded Whether any invoices need attention
    /// @return performData Data needed for the upkeep
    /// @dev Part of Chainlink Automation
    function checkUpkeep(
        bytes calldata checkData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // TODO: Implement checkUpkeep
    }

    /// @notice Performs automated actions on invoices
    /// @param performData Data needed for the upkeep
    /// @dev Part of Chainlink Automation
    /// @dev Handles late payments and notifications
    function performUpkeep(bytes calldata performData) external override {
        // TODO: Implement performUpkeep
    }

    /*//////////////////////////////////////////////////////////////
                                  VRF
    //////////////////////////////////////////////////////////////*/
    /// @notice Requests a random auditor for an invoice
    /// @param invoiceId The ID of the invoice to audit
    /// @dev Uses Chainlink VRF for random selection
    function requestAuditor(uint256 invoiceId) external nonReentrant {
        // TODO: Implement requestAuditor
    }

    /// @notice Receives random number from VRF and assigns auditor
    /// @param requestId The ID of the VRF request
    /// @param randomWords Array of random numbers
    /// @dev Called by VRF Coordinator
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // TODO: Implement fulfillRandomWords
        // Assign Auditor
    }

    /*//////////////////////////////////////////////////////////////
                         MARKETPLACE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Lists an invoice for sale
    /// @param invoiceId The ID of the invoice to list
    /// @dev Can only be called by the invoice owner
    function listForSale(uint256 invoiceId) external nonReentrant {
        if (ownerOf(invoiceId) != msg.sender) {
            revert InvoiceNFT__NotOwner();
        }
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = i_priceFeed.latestRoundData();

        if (price <= 0) revert InvoiceNFT__InvalidPriceFeed();
        if (updatedAt == 0) revert InvoiceNFT__StalePriceFeed();
        if (answeredInRound < roundId) revert InvoiceNFT__StalePriceFeed();

        invoices[invoiceId].isListed = true;

        emit InvoiceListed(invoiceId, invoices[invoiceId].amount);
    }

    /// @notice Purchases a listed invoice
    /// @param invoiceId The ID of the invoice to purchase
    /// @dev Transfers USDC from buyer to seller and protocol
    /// @dev Transfers NFT ownership to buyer
    function buyWithUSDC(uint256 invoiceId) external nonReentrant {
        if (!invoices[invoiceId].isListed) {
            revert InvoiceNFT__NotListed();
        }
        uint256 amount = invoices[invoiceId].amount;
        uint256 fee = (amount * FEE_PERCENTAGE) / PRECISION;

        USDC.transferFrom(msg.sender, owner(), fee); // protocol fee
        USDC.transferFrom(msg.sender, invoices[invoiceId].payer, amount - fee); //  seller payout

        _transfer(owner(), msg.sender, invoiceId);
    }

    function cancelListing(uint256 invoiceId) external nonReentrant {
        Invoice memory invoice = invoices[invoiceId];
        if (invoice.payer != msg.sender) {
            revert InvoiceNFT__NotPayer();
        }
        if (!invoice.isListed) {
            revert InvoiceNFT__NotListed();
        }
        invoices[invoiceId].isListed = false;
        emit InvoiceCanceled(invoiceId);
    }

    /*//////////////////////////////////////////////////////////////
    INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Handles the response from Chainlink Functions
    /// @param requestId The ID of the request
    /// @param response The response from the Functions request
    /// @dev Decodes the response and updates the invoice payment status
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

    /*//////////////////////////////////////////////////////////////
    VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Gets the USD value of an invoice
    /// @param invoiceId The ID of the invoice
    /// @return The value in USD
    /// @dev Uses PriceOracle for conversion
    function getInvoiceValueInUsd(
        uint256 invoiceId
    ) external view returns (uint256) {
        uint256 amountInUsdc = invoices[invoiceId].amount;
        return i_priceOracle.convertoUsd(amountInUsdc);
    }

    /// @notice Gets the full invoice details
    /// @param invoiceId The ID of the invoice
    /// @return The Invoice struct containing all details
    function getInvoice(
        uint256 invoiceId
    ) external view returns (Invoice memory) {
        return invoices[invoiceId];
    }
}
