pragma solidity >=0.5.0;

import '../interfaces/ISwappiPair.sol';
import '../interfaces/IERC20.sol';

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
                hex'29175648b4d47db69c4f0b9cb0a84dc06e44408bfb4490c586901d9a645bfa92' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = ISwappiPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'SwappiLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }
    function _f(uint x0, uint y) internal pure returns (uint) {
        return x0*(y*y/1e18*y/1e18)/1e18+(x0*x0/1e18*x0/1e18)*y/1e18;
    }

    function _d(uint x0, uint y) internal pure returns (uint) {
        return 3*x0*(y*y/1e18)/1e18+(x0*x0/1e18*x0/1e18);
    }

    function _get_y(uint x0, uint xy, uint y) internal pure returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            if (k < xy) {
                uint dy = (xy - k)*1e18/_d(x0, y);
                y = y + dy;
            } else {
                uint dy = (k - xy)*1e18/_d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }
    function _get_y_amountIn(uint x0, uint xy, uint y) internal pure returns (uint) {
        for (uint i = 0; i < 255; i++) {
            uint y_prev = y;
            uint k = _f(x0, y);
            if (k < xy) {
                uint dy = divUp((xy - k)*1e18, _d(x0, y));
                y = y + dy;
            } else {
                uint dy = (k - xy)*1e18/_d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }
    function _k(uint x, uint y, uint decimals0, uint decimals1) internal pure returns (uint) {
        uint _x = x * 1e18 / decimals0;
        uint _y = y * 1e18 / decimals1;
        uint _a = (_x * _y) / 1e18;
        uint _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return _a * _b / 1e18;  // x3y+y3x >= k
    }
    function _getAmountOut(uint amountIn, uint _reserve0, uint _reserve1, uint decimals0, uint decimals1) internal pure returns (uint) {
        uint xy =  _k(_reserve0, _reserve1, decimals0, decimals1);
        _reserve0 = _reserve0 * 1e18 / decimals0;
        _reserve1 = _reserve1 * 1e18 / decimals1;
        amountIn = amountIn * 1e18 / decimals0;
        uint y = _reserve1 - _get_y(amountIn+_reserve0, xy, _reserve1);
        return y * decimals1 / 1e18;
    }
    function divUp(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b != 0, "Errors.ZERO_DIVISION");

        // Equivalent to:
        // result = a == 0 ? 0 : 1 + (a - 1) / b;
        assembly {
            result := mul(iszero(iszero(a)), add(1, div(sub(a, 1), b)))
        }
    }
    function _getAmountIn(uint amountOut, uint _reserve0, uint _reserve1, uint decimals0, uint decimals1) internal pure returns (uint) {
        uint xy =  _k(_reserve0, _reserve1, decimals0, decimals1);
        _reserve0 = _reserve0 * 1e18 / decimals0;
        _reserve1 = _reserve1 * 1e18 / decimals1;
        amountOut = amountOut * 1e18 / decimals0;
        uint y = _get_y_amountIn(_reserve1- amountOut, xy, _reserve0) - _reserve0;
        return y * decimals0 / 1e18;
    }
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint decimalsIn, uint decimalsOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'SwappiLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        (uint _reserve0, uint _reserve1) = (reserveIn, reserveOut);
        uint amountInWithFee = amountIn.mul(9997)/10000;
        amountInWithFee = amountInWithFee * 1e18 / decimalsIn;
        return _getAmountOut(amountInWithFee, _reserve0, _reserve1, decimalsIn, decimalsOut);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint decimalsIn, uint decimalsOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'SwappiLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwappiLibrary: INSUFFICIENT_LIQUIDITY');
        // uint numerator = reserveIn.mul(amountOut).mul(10000);
        // uint denominator = reserveOut.sub(amountOut).mul(9997);
        // amountIn = (numerator / denominator).add(1);
        amountOut = amountOut * 1e18 / decimalsOut;
        (uint _reserve0, uint _reserve1) = (reserveIn, reserveOut);
        return divUp(_getAmountIn(amountOut, _reserve0, _reserve1, decimalsIn, decimalsOut).mul(10000), 9997);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwappiLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            uint decimalsIn = 10**uint256(IERC20(path[i]).decimals());
            uint decimalsOut = 10**uint256(IERC20(path[i+1]).decimals());
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, decimalsIn, decimalsOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'SwappiLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            uint decimalsIn = 10**uint256(IERC20(path[i-1]).decimals());
            uint decimalsOut = 10**uint256(IERC20(path[i]).decimals());
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, decimalsIn, decimalsOut);
        }
    }
}
