// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface IPool {
    function flashLoan(
        address receiverAddress,
        address asset,
        uint256 amount,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}
