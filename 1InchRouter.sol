pragma solidity ^0.6.6;

interface I1inchRouter {
    function getAmountsOut(address tokenIn, uint256 amountIn, address[] calldata path) external returns (uint256[] memory amounts);
    function swap(address fromToken, address toToken, uint256 amount, uint256 minReturn, bytes calldata data) external returns (uint256 returnAmount);
}
