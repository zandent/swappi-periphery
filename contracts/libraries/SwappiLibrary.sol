pragma solidity >=0.5.0;

import '../interfaces/ISwappiPair.sol';

import "./SafeMath.sol";

library SwappiLibrary {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'SwappiLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'SwappiLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'f8fb03b41506dcfde2d9f61a6b5cbb72395e938c253a7f26eb1fcb093bd1709e' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = ISwappiPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB,uint256[2] memory normalizedWeights) internal pure returns (uint amountB) {
        require(amountA > 0, 'SwappiLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB/normalizedWeights[1]) / (reserveA/normalizedWeights[0]);
    }
    function _getAmountOut(uint amountIn, uint _reserve0, uint _reserve1, address tokenIn, address tokenOut, address pool) internal view returns (uint) {
        return ISwappiPair(pool).onSwapGivenIn(
            tokenIn,
            tokenOut,
            amountIn,
            _reserve0,
            _reserve1
        );
    }
    function _getAmountIn(uint amountOut, uint _reserve0, uint _reserve1, address tokenIn, address tokenOut, address pool) internal view returns (uint) {
        return ISwappiPair(pool).onSwapGivenIn(
            tokenIn,
            tokenOut,
            amountOut,
            _reserve0,
            _reserve1
        );
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut, address factory) internal view returns (uint amountOut) {
        require(amountIn > 0, 'SwappiLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        address pool = pairFor(factory, tokenIn, tokenOut);
        (uint _reserve0, uint _reserve1) = (reserveIn, reserveOut);
        uint amountInWithFee = amountIn.mul(9997)/10000;
        return _getAmountOut(amountInWithFee, _reserve0, _reserve1, tokenIn, tokenOut, pool);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut, address factory) internal view returns (uint amountIn) {
        require(amountOut > 0, 'SwappiLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        address pool = pairFor(factory, tokenIn, tokenOut);
        (uint _reserve0, uint _reserve1) = (reserveIn, reserveOut);
        return _getAmountIn(amountOut, _reserve0, _reserve1, tokenIn, tokenOut, pool).mul(10000)/9997;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwappiLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, path[i], path[i + 1], factory);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwappiLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, path[i - 1], path[i], factory);
        }
    }
}
