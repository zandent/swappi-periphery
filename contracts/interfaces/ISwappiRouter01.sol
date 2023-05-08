pragma solidity >=0.6.2;

interface ISwappiRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    struct addLiquidityParam {
        address tokenA;
        address tokenB;
        uint256[2] normalizedWeights;
        uint amountADesired;
        uint amountBDesired;
        address to;    
    }
    struct addLiquidityParamForOneToken {
        address tokenA;
        address tokenB;
        uint liquidity;
        uint tokenIndex;
        uint amountAMin;
        uint amountBMin;
        address to;    
    }
    struct rmLiquidityParam {
        address tokenA;
        address tokenB;
        uint liquidity;
        uint amountAMin;
        uint amountBMin;
        address to;    
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256[2] calldata normalizedWeights,
        uint amountADesired,
        uint amountBDesired,
        uint lquidityMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint256[2] calldata normalizedWeights,
        uint amountTokenDesired,
        uint lquidityMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB, uint256[2] calldata normalizedWeights) external view returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}
