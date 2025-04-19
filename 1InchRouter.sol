
pragma solidity ^0.6.6;

interface I1inchRouter {
    function getAmountsOut(address tokenIn, uint256 amountIn, address[] calldata path) external returns (uint256[] memory amounts);
}
