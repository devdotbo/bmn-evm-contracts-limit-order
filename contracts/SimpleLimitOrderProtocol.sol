// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "./OrderMixin.sol";

/**
 * @title Simple Limit Order Protocol for Bridge-Me-Not
 * @notice Stripped down version - no pausing, no whitelisting, no staking
 * @dev Designed to work with CrossChainEscrowFactory as an extension
 */
contract SimpleLimitOrderProtocol is 
    EIP712("Bridge-Me-Not Orders", "1"),
    OrderMixin
{
    constructor(IWETH _weth) OrderMixin(_weth) {}

    function DOMAIN_SEPARATOR() external view returns(bytes32) {
        return _domainSeparatorV4();
    }
}