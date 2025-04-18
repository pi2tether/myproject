// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

interface I1inchRouter {
    function getAmountsOut(address tokenIn, uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}