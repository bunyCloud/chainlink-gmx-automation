// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MarketAutomation} from "../src/MarketAutomation.sol";
import {TestData} from "./TestData.sol";
import {LibGMXEventLogDecoder} from "../src/libraries/LibGMXEventLogDecoder.sol";
// openzeppelin
import {ERC20Mock} from "openzeppelin/mocks/ERC20Mock.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
// gmx-synthetics
import {DataStore} from "gmx-synthetics/data/DataStore.sol";
import {Reader} from "gmx-synthetics/reader/Reader.sol";
import {OrderHandler} from "gmx-synthetics/exchange/OrderHandler.sol";
import {Market} from "gmx-synthetics/market/Market.sol";
import {OracleUtils} from "gmx-synthetics/oracle/OracleUtils.sol";
// chainlink
import {ILogAutomation, Log} from "chainlink/dev/automation/2_1/interfaces/ILogAutomation.sol";
import {StreamsLookupCompatibleInterface} from
    "chainlink/dev/automation/2_1/interfaces/StreamsLookupCompatibleInterface.sol";
// forge-std
import {Test, console} from "forge-std/Test.sol";

contract MarketAutomationTest_End2End is Test, TestData {
    uint256 internal s_forkId;

    DataStore internal s_dataStore;
    Reader internal s_reader;
    OrderHandler internal s_orderHandler;
    MarketAutomation internal s_marketAutomation;

    Market.Props[] internal s_marketProps;
    Log internal s_log;

    bytes32 internal constant KEY = keccak256(abi.encode("MarketAutomationTest_checkLog"));

    function setUp() public {
        s_forkId = vm.createSelectFork(vm.envString(ARBITRUM_GOERLI_URL_LABEL));
        s_dataStore = DataStore(vm.envAddress(DATA_STORE_LABEL));
        s_reader = Reader(vm.envAddress(READER_LABEL));
        s_orderHandler = OrderHandler(vm.envAddress(ORDER_HANDLER_LABEL));
        s_marketAutomation = new MarketAutomation(s_dataStore, s_reader, s_orderHandler);
        Market.Props[] memory marketProps = s_reader.getMarkets(s_dataStore, 0, 1);
        for (uint256 i = 0; i < marketProps.length; i++) {
            s_marketProps.push(marketProps[i]);
        }

        address market = s_marketProps[0].marketToken;
        address[] memory swapPath = new address[](s_marketProps.length);
        for (uint256 i = 0; i < s_marketProps.length; i++) {
            swapPath[i] = s_marketProps[i].marketToken;
        }
        s_log = _generateValidLog(
            address(this),
            block.number,
            LibGMXEventLogDecoder.EventLog2.selector,
            "OrderCreated",
            market,
            swapPath,
            KEY,
            2,
            swapPath,
            swapPath
        );
    }

    //// command: `forge test --match-test test_checkLog_realData_success -vvvvv`
    function test_checkLog_realData_success() public {
        s_marketAutomation = MarketAutomation(0xE0886d9baAaD385F37d460A4ec7b32b79a3731e0);
        string[] memory expectedFeedIds = new string[](2);
        expectedFeedIds[0] = "0xbf1febc8c335cb236c1995c1007a928a3f7ae8307a1a20cb31334e6d316c62d1";
        expectedFeedIds[1] = "0x4554482d5553442d415242495452554d2d544553544e45540000000000000000";

        bytes memory encodedRevert = abi.encodeWithSelector(
            StreamsLookupCompatibleInterface.StreamsLookup.selector,
            "feedIdHex",
            expectedFeedIds,
            "blockNumber",
            38174768,
            hex"23e61805fed7a15e0190077bd450bab888d6e572caaf722cb95f2e217fb42a56000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000020000000000000000000000007b7c6c49fa99b37270077fbfa398748c27046984000000000000000000000000e39ab88f8a4777030a534146a9ca3b52bd5d43a3"
        );

        vm.expectRevert(encodedRevert);

        s_marketAutomation.checkLog(_realEventLog2Data_MikeStone(), EMPTY_BYTES);
    }

    function test_MarketAutomation_End2End_success() public {
        string[] memory expectedFeedIds = new string[](2);
        expectedFeedIds[0] = vm.envString("MARKET_FORK_TEST_FEED_ID_0");
        expectedFeedIds[1] = vm.envString("MARKET_FORK_TEST_FEED_ID_1");
        address[] memory expectedMarketAddresses = new address[](2);
        expectedMarketAddresses[0] = vm.envAddress("MARKET_ADDRESS_0");
        expectedMarketAddresses[1] = vm.envAddress("MARKET_ADDRESS_1");
        // Expected revert
        bytes memory encodedRevert = abi.encodeWithSelector(
            StreamsLookupCompatibleInterface.StreamsLookup.selector,
            "feedIdHex",
            expectedFeedIds,
            "blockNumber",
            block.number,
            abi.encode(KEY, expectedMarketAddresses)
        );
        vm.expectRevert(encodedRevert);
        s_marketAutomation.checkLog(s_log, EMPTY_BYTES);

        // Off-chain, decode revert and construct callback data
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encode(expectedFeedIds[0]);
        values[1] = abi.encode(expectedFeedIds[1]);
        (bool result, bytes memory performData) =
            s_marketAutomation.checkCallback(values, abi.encode(KEY, expectedMarketAddresses));
        assertTrue(result);
        assertEq(performData, abi.encode(values, abi.encode(KEY, expectedMarketAddresses)));

        // Pass perfromData to performUpkeep
        OracleUtils.SetPricesParams memory expectedParams;
        expectedParams.realtimeFeedTokens = expectedMarketAddresses;
        expectedParams.realtimeFeedData = values;
        vm.mockCall(
            address(s_orderHandler),
            abi.encodeWithSelector(OrderHandler.executeOrder.selector, KEY, expectedParams),
            abi.encode("")
        );
        s_marketAutomation.performUpkeep(performData);
    }
}

contract MarketAutomationTest_checkLog is Test, TestData {
    uint256 internal s_forkId;

    DataStore internal s_dataStore;
    Reader internal s_reader;
    OrderHandler internal s_orderHandler;
    MarketAutomation internal s_marketAutomation;

    Market.Props[] internal s_marketProps;
    Log internal s_log;

    bytes32 internal constant KEY = keccak256(abi.encode("MarketAutomationTest_checkLog"));

    function setUp() public {
        s_forkId = vm.createSelectFork(vm.envString(ARBITRUM_GOERLI_URL_LABEL));
        s_dataStore = DataStore(vm.envAddress(DATA_STORE_LABEL));
        s_reader = Reader(vm.envAddress(READER_LABEL));
        s_orderHandler = OrderHandler(vm.envAddress(ORDER_HANDLER_LABEL));
        s_marketAutomation = new MarketAutomation(s_dataStore, s_reader, s_orderHandler);
        Market.Props[] memory marketProps = s_reader.getMarkets(s_dataStore, 0, 1);
        for (uint256 i = 0; i < marketProps.length; i++) {
            s_marketProps.push(marketProps[i]);
        }

        address market = s_marketProps[0].marketToken;
        address[] memory swapPath = new address[](s_marketProps.length);
        for (uint256 i = 0; i < s_marketProps.length; i++) {
            swapPath[i] = s_marketProps[i].marketToken;
        }
        s_log = _generateValidLog(
            address(this),
            block.number,
            LibGMXEventLogDecoder.EventLog2.selector,
            "OrderCreated",
            market,
            swapPath,
            KEY,
            2,
            swapPath,
            swapPath
        );
    }

    //////////////
    // UNIT TESTS
    //////////////

    function test_checkLog_success() public {
        string[] memory expectedFeedIds = new string[](2);
        expectedFeedIds[0] = vm.envString("MARKET_FORK_TEST_FEED_ID_0");
        expectedFeedIds[1] = vm.envString("MARKET_FORK_TEST_FEED_ID_1");
        address[] memory expectedMarketAddresses = new address[](2);
        expectedMarketAddresses[0] = vm.envAddress("MARKET_ADDRESS_0");
        expectedMarketAddresses[1] = vm.envAddress("MARKET_ADDRESS_1");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamsLookupCompatibleInterface.StreamsLookup.selector,
                "feedIdHex",
                expectedFeedIds,
                "blockNumber",
                block.number,
                abi.encode(KEY, expectedMarketAddresses)
            )
        );
        s_marketAutomation.checkLog(s_log, EMPTY_BYTES);
    }

    function test_checkLog_MarketAutomation_IncorrectEventName_reverts() public {
        string memory incorrectLogName = "DepositCreated";
        address[] memory swapPath;
        s_log = _generateValidLog(
            address(this),
            block.number,
            LibGMXEventLogDecoder.EventLog2.selector,
            incorrectLogName,
            s_marketProps[0].marketToken,
            swapPath,
            KEY,
            2,
            swapPath,
            swapPath
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketAutomation.MarketAutomation_IncorrectEventName.selector, incorrectLogName, "OrderCreated"
            )
        );
        s_marketAutomation.checkLog(s_log, EMPTY_BYTES);
    }

    function test_checkLog_MarketAutomation_IncorrectOrderType_reverts() public {
        address[] memory swapPath;
        s_log = _generateValidLog(
            address(this),
            block.number,
            LibGMXEventLogDecoder.EventLog2.selector,
            "OrderCreated",
            s_marketProps[0].marketToken,
            swapPath,
            KEY,
            5,
            swapPath,
            swapPath
        );
        vm.expectRevert(abi.encodeWithSelector(MarketAutomation.MarketAutomation_IncorrectOrderType.selector, 5));
        s_marketAutomation.checkLog(s_log, EMPTY_BYTES);
    }

    ///////////////////////////
    // FUZZ TESTS
    ///////////////////////////

    function test_fuzz_checkLog_revertsInEveryCase(
        address msgSender,
        uint256 blockNumber,
        bool logSelectorIndex,
        string memory eventName,
        address market,
        address[] memory swapPath,
        bytes32 key,
        uint256 orderType,
        address[] memory longTokenSwapPath,
        address[] memory shortTokenSwapPath
    ) public {
        bytes32 logSelector =
            logSelectorIndex ? LibGMXEventLogDecoder.EventLog1.selector : LibGMXEventLogDecoder.EventLog2.selector;
        Log memory log = _generateValidLog(
            msgSender,
            blockNumber,
            logSelector,
            eventName,
            market,
            swapPath,
            key,
            orderType,
            longTokenSwapPath,
            shortTokenSwapPath
        );
        vm.expectRevert();
        s_marketAutomation.checkLog(log, EMPTY_BYTES);
    }
}

contract MarketAutomationTest_checkCallback is Test, TestData {
    DataStore internal s_dataStore;
    Reader internal s_reader;
    OrderHandler internal s_orderHandler;
    MarketAutomation internal s_marketAutomation;

    function setUp() public {
        s_dataStore = DataStore(vm.envAddress(DATA_STORE_LABEL));
        s_reader = Reader(vm.envAddress(READER_LABEL));
        s_orderHandler = OrderHandler(vm.envAddress(ORDER_HANDLER_LABEL));
        s_marketAutomation = new MarketAutomation(s_dataStore, s_reader, s_orderHandler);
    }

    function test_checkCallback_success(bytes[] calldata values, bytes calldata extraData) public {
        (bool result, bytes memory data) = s_marketAutomation.checkCallback(values, extraData);
        assertTrue(result);
        assertEq(data, abi.encode(values, extraData));
    }
}

contract MarketAutomationTest_performUpkeep is Test, TestData {
    DataStore internal s_dataStore;
    Reader internal s_reader;
    OrderHandler internal s_orderHandler;
    MarketAutomation internal s_marketAutomation;

    function setUp() public {
        s_dataStore = DataStore(vm.envAddress(DATA_STORE_LABEL));
        s_reader = Reader(vm.envAddress(READER_LABEL));
        s_orderHandler = OrderHandler(vm.envAddress(ORDER_HANDLER_LABEL));
        s_marketAutomation = new MarketAutomation(s_dataStore, s_reader, s_orderHandler);
    }

    function test_performUpkeep_success(bytes[] memory values, bytes32 key, address[] memory marketAddresses) public {
        bytes memory extraData = abi.encode(key, marketAddresses);
        bytes memory performData = abi.encode(values, extraData);
        OracleUtils.SetPricesParams memory expectedParams;
        expectedParams.realtimeFeedTokens = marketAddresses;
        expectedParams.realtimeFeedData = values;
        vm.mockCall(
            address(s_orderHandler),
            abi.encodeWithSelector(OrderHandler.executeOrder.selector, key, expectedParams),
            abi.encode("")
        );
        s_marketAutomation.performUpkeep(performData);
    }
}
