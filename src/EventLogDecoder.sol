// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {EventUtils} from "gmx-synthetics/event/EventUtils.sol";
import {ILogAutomation} from "./ILogAutomation.sol";

contract EventLogDecoder {

    error IncorrectLogSelector(bytes32 logSelector, bytes32 expectedLogSelector);
    error IncorrectBytes32ItemsLength(uint256 length);
    error KeyNotFound();
    error IncorrectAddressItemsLength(uint256 length);
    error MarketNotFound();
    error IncorrectUintItemsLength(uint256 length);
    error OrderTypeNotFound();
    error IncorrectAddressArrayItemsLength(uint256 length);
    error SwapPathNotFound();

    //////////
    // EVENTS
    //////////

    // Logs from gmx-synthetics/event/EventEmitter.sol
    event EventLog1(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed topic1,
        EventUtils.EventLogData eventData
    );

    event EventLog2(
        address msgSender,
        string eventName,
        string indexed eventNameHash,
        bytes32 indexed topic1,
        bytes32 indexed topic2,
        EventUtils.EventLogData eventData
    );

    ////////////////////////////
    // EVENT DECODING FUNCTIONS
    ////////////////////////////

    // TODO: decode EventLog1

    /// @notice Decode an EventLog2 event
    /// @dev This function reverts if the log is not an EventLog2 event
    /// @dev We only decode non-indexed data from the log here (), hence why eventNameHash, topic1 and topic2 are not returned.
    /// @param log the log to decode
    /// @return msgSender the sender of the transaction that emitted the log
    /// @return eventName the name of the event
    /// @return eventData the EventUtils EventLogData struct
    function _decodeEventLog2(ILogAutomation.Log calldata log)
        internal
        pure
        returns (
            address msgSender,
            string memory eventName,
            EventUtils.EventLogData memory eventData
        )
    {
        // Ensure that the log is an EventLog2 event
        if (log.topics[0] != EventLog2.selector) {
            revert IncorrectLogSelector(log.topics[0], EventLog2.selector);
        }

        (msgSender, eventName, eventData) =
            abi.decode(log.data, (address, string, EventUtils.EventLogData));
    }

    /////////////////////////////////////////
    // EVENTUTILS.EVENTDATA DECODER FUNCTIONS
    /////////////////////////////////////////
    // Functions to retrieve data from EventUtils.EventData structs

    // Need: key, market, orderType, swapPath
    /// @notice Retrieve the key, market, orderType and swapPath from the EventUtils EventLogData struct
    /// @dev This function reverts if any of the keys (key, market, orderType and swapPath) are not present in the EventUtils EventLogData struct
    /// @param eventData the EventUtils EventLogData struct
    /// @return key the key
    /// @return market the market
    /// @return orderType the orderType
    /// @return swapPath the swapPath
    function _decodeEventData(EventUtils.EventLogData memory eventData)
        internal
        pure
        returns (
            bytes32 key,
            address market,
            uint256 orderType,
            address[] memory swapPath
        )
    {
        // Get the key from the eventData
        EventUtils.Bytes32KeyValue[] memory bytes32Items = eventData.bytes32Items.items;
        if (bytes32Items.length == 0) revert IncorrectBytes32ItemsLength(bytes32Items.length);
        bool foundKey;
        for (uint256 i = 0; i < bytes32Items.length; i++) {
            if (keccak256(abi.encode(bytes32Items[i].key)) == keccak256(abi.encode("key"))) {
                key = bytes32Items[i].value;
                foundKey = true;
                break;
            }
        }
        if (!foundKey) revert KeyNotFound();

        // Extract the market from the event data
        EventUtils.AddressKeyValue[] memory addressItems = eventData.addressItems.items;
        if (addressItems.length == 0) revert IncorrectAddressItemsLength(addressItems.length);
        bool foundMarket;
        for (uint256 i = 0; i < addressItems.length; i++) {
            if (keccak256(abi.encode(addressItems[i].key)) == keccak256(abi.encode("market"))) {
                market = addressItems[i].value;
                foundMarket = true;
                break;
            }
        }
        if (!foundMarket) revert MarketNotFound();

        // Extract the orderType from the event data
        EventUtils.UintKeyValue[] memory uintItems = eventData.uintItems.items;
        if (uintItems.length == 0) revert IncorrectUintItemsLength(uintItems.length);
        bool foundOrderType;
        for (uint256 i = 0; i < uintItems.length; i++) {
            if (keccak256(abi.encode(uintItems[i].key)) == keccak256(abi.encode("orderType"))) {
                orderType = uintItems[i].value;
                foundOrderType = true;
                break;
            }
        }
        if (!foundOrderType) revert OrderTypeNotFound();

        // Extract the swapPath from the event data
        EventUtils.AddressArrayKeyValue[] memory addressArrayItems = eventData.addressItems.arrayItems;
        if (addressArrayItems.length == 0) revert IncorrectAddressArrayItemsLength(addressArrayItems.length);
        bool foundSwapPath;
        for (uint256 i = 0; i < addressArrayItems.length; i++) {
            if (keccak256(abi.encode(addressArrayItems[i].key)) == keccak256(abi.encode("swapPath"))) {
                swapPath = addressArrayItems[i].value;
                foundSwapPath = true;
                break;
            }
        }
        if (!foundSwapPath) revert SwapPathNotFound();
    }
}