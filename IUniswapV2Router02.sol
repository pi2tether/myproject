pragma solidity ^0.6.6;

interface IUniswapV2Router02 {
    function getAmountsOut(uint amountIn, address[] calldata path) external returns (uint[] memory amounts);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}
