pragma solidity =0.6.6;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/ISwappiRouter01.sol';
import './interfaces/ISwappiFactory.sol';
import './libraries/SwappiLibrary.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract SwappiRouterWeighted is ISwappiRouter01 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'SwappiRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        addLiquidityParam memory params
    ) internal virtual returns (uint amountA, uint amountB, uint liquidity, address pair) {
        // create the pair if it doesn't exist yet
        if (ISwappiFactory(factory).getPair(params.tokenA, params.tokenB) == address(0)) {
            ISwappiFactory(factory).createPair(params.tokenA, params.tokenB, params.normalizedWeights);
        }
        pair = ISwappiFactory(factory).getPair(params.tokenA, params.tokenB);
        (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, params.tokenA, params.tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (params.amountADesired, params.amountBDesired);
        } else {
            uint amountBOptimal = SwappiLibrary.quote(params.amountADesired, reserveA, reserveB, params.normalizedWeights);
            if (amountBOptimal <= params.amountBDesired) {
                require(amountBOptimal >= params.amountBMin, 'SwappiRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (params.amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = SwappiLibrary.quote(params.amountBDesired, reserveB, reserveA, params.normalizedWeights);
                assert(amountAOptimal <= params.amountADesired);
                require(amountAOptimal >= params.amountAMin, 'SwappiRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, params.amountBDesired);
            }
        }
        uint[] memory reserves = new uint[] (2); reserves[0] = reserveA; reserves[1] = reserveB;
        uint[] memory amounts = new uint[] (2); amounts[0] = amountA; amounts[1] = amountB;
        (, liquidity) = ISwappiPair(pair).onJoinPool(params.to, reserves, amounts, 0);
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256[2] calldata normalizedWeights,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        addLiquidityParam memory params = addLiquidityParam({
         tokenA: tokenA,
         tokenB: tokenB,
         normalizedWeights: normalizedWeights,
         amountADesired: amountADesired,
         amountBDesired: amountBDesired,
         amountAMin: amountAMin,
         amountBMin: amountBMin,
         to: to
        });
        address pair;
        (amountA, amountB, liquidity, pair) = _addLiquidity(params);
        // address pair = SwappiLibrary.pairFor(factory, tokenA, tokenB);
        // (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, tokenA, tokenB);
        // (, liquidity) = ISwappiPair(pair).onJoinPool(to, [reserveA, reserveB], [amountA, amountB], 0);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
    }
    function addLiquidityETH(
        address token,
        uint256[2] calldata normalizedWeights,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        addLiquidityParam memory params;
        if (token < WETH) {
            params = addLiquidityParam({
            tokenA: token,
            tokenB: WETH,
            normalizedWeights: normalizedWeights,
            amountADesired: amountTokenDesired,
            amountBDesired: msg.value,
            amountAMin: amountTokenMin,
            amountBMin: amountETHMin,
            to: to
            });
        }else{
            params = addLiquidityParam({
            tokenA: WETH,
            tokenB: token,
            normalizedWeights: normalizedWeights,
            amountADesired: msg.value,
            amountBDesired: amountTokenDesired,
            amountAMin: amountETHMin,
            amountBMin: amountTokenMin,
            to: to
            });
        }
        address pair;
        (amountToken, amountETH, liquidity, pair) = _addLiquidity(
            params
        );
        // address pair = SwappiLibrary.pairFor(factory, token, WETH);
        // (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, token, WETH);
        // (reserveA, reserveB) = token < WETH ? (reserveA, reserveB) : (reserveB, reserveA);
        // (uint amountA, uint amountB) = token < WETH ? (amountTokenDesired, amountETH) : (amountETH, amountTokenDesired);
        // (, liquidity) = ISwappiPair(pair).onJoinPool(to, [reserveA, reserveB], [amountA, amountB], 0);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }
    function _removeLiquidity(
        rmLiquidityParam memory params
    )internal virtual returns (uint amountA, uint amountB){
        address pair = SwappiLibrary.pairFor(factory, params.tokenA, params.tokenB);
        (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, params.tokenA, params.tokenB);
        // (reserveA, reserveB) = tokenA < tokenB ? (reserveA, reserveB) : (reserveB, reserveA);
        uint[] memory reserves = new uint[] (2); reserves[0] = reserveA; reserves[1] = reserveB;
        (amountA, amountB) = ISwappiPair(pair).onExitPool(params.to, reserves, params.liquidity, 2); //2 means return proptional tokens        
        require(amountA >= params.amountAMin, 'SwappiRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= params.amountBMin, 'SwappiRouter: INSUFFICIENT_B_AMOUNT');
    }
    // **** REMOVE LIQUIDITY ****
    //remove liquidity and return proptional tokens
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        rmLiquidityParam memory params = rmLiquidityParam({
            tokenA: tokenA,
            tokenB: tokenB,
            liquidity: liquidity,
            amountAMin: amountAMin,
            amountBMin: amountBMin,
            to: to
        });
        (amountA, amountB) = _removeLiquidity(params);
        // address pair = SwappiLibrary.pairFor(factory, tokenA, tokenB);
        // (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, tokenA, tokenB);
        // (reserveA, reserveB) = tokenA < tokenB ? (reserveA, reserveB) : (reserveB, reserveA);
        // (uint amount0, uint amount1) = ISwappiPair(pair).onExitPool(to, [reserveA, reserveB], liquidity, 2); //2 means return proptional tokens
        // ISwappiPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair // no need to transfer to pair. Pair will burn for user directly
        // (address token0,) = SwappiLibrary.sortTokens(tokenA, tokenB);
        // (amountA, amountB) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
        // require(amountA >= amountAMin, 'SwappiRouter: INSUFFICIENT_A_AMOUNT');
        // require(amountB >= amountBMin, 'SwappiRouter: INSUFFICIENT_B_AMOUNT');
        TransferHelper.safeTransfer(tokenA, to, amountA);
        TransferHelper.safeTransfer(tokenB, to, amountB);
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        rmLiquidityParam memory params;
        if (token < WETH) {
            params = rmLiquidityParam({
            tokenA: token,
            tokenB: WETH,
            liquidity: liquidity,
            amountAMin: amountTokenMin,
            amountBMin: amountETHMin,
            to: to
            });
            (amountToken, amountETH) = _removeLiquidity(params);
        }else{
            params = rmLiquidityParam({
            tokenA: WETH,
            tokenB: token,
            liquidity: liquidity,
            amountAMin: amountETHMin,
            amountBMin: amountTokenMin,
            to: to
            });
            (amountETH, amountToken) = _removeLiquidity(params);
        }
        
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = SwappiLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        ISwappiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = SwappiLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        ISwappiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    // function removeLiquidityETHSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline
    // ) public virtual override ensure(deadline) returns (uint amountETH) {
    //     (, amountETH) = removeLiquidity(
    //         token,
    //         WETH,
    //         liquidity,
    //         amountTokenMin,
    //         amountETHMin,
    //         address(this),
    //         deadline
    //     );
    //     TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
    //     IWETH(WETH).withdraw(amountETH);
    //     TransferHelper.safeTransferETH(to, amountETH);
    // }
    // function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
    //     address token,
    //     uint liquidity,
    //     uint amountTokenMin,
    //     uint amountETHMin,
    //     address to,
    //     uint deadline,
    //     bool approveMax, uint8 v, bytes32 r, bytes32 s
    // ) external virtual override returns (uint amountETH) {
    //     address pair = SwappiLibrary.pairFor(factory, token, WETH);
    //     uint value = approveMax ? uint(-1) : liquidity;
    //     ISwappiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    //     amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
    //         token, liquidity, amountTokenMin, amountETHMin, to, deadline
    //     );
    // }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            // (address token0,) = SwappiLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            // (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            (uint reserveA, uint reserveB) = SwappiLibrary.getReserves(factory, input, output);
            address to = i < path.length - 2 ? SwappiLibrary.pairFor(factory, output, path[i + 2]) : _to;
            amountOut = ISwappiPair(SwappiLibrary.pairFor(factory, input, output)).onSwap(
                false, input, output, amountOut, reserveA, reserveB, to
            );
        }

    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SwappiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        _swap(amounts, path, to);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = SwappiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'SwappiRouter: EXCESSIVE_INPUT_AMOUNT');
        _swap(amounts, path, to);
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SwappiRouter: INVALID_PATH');
        amounts = SwappiLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        _swap(amounts, path, to);
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SwappiRouter: INVALID_PATH');
        amounts = SwappiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'SwappiRouter: EXCESSIVE_INPUT_AMOUNT');
        _swap(amounts, path, address(this));
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'SwappiRouter: INVALID_PATH');
        amounts = SwappiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        _swap(amounts, path, address(this));
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'SwappiRouter: INVALID_PATH');
        amounts = SwappiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'SwappiRouter: EXCESSIVE_INPUT_AMOUNT');
        _swap(amounts, path, to);
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(SwappiLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // // **** SWAP (supporting fee-on-transfer tokens) ****
    // // requires the initial amount to have already been sent to the first pair
    // function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
    //     for (uint i; i < path.length - 1; i++) {
    //         (address input, address output) = (path[i], path[i + 1]);
    //         (address token0,) = SwappiLibrary.sortTokens(input, output);
    //         ISwappiPair pair = ISwappiPair(SwappiLibrary.pairFor(factory, input, output));
    //         uint amountInput;
    //         uint amountOutput;
    //         { // scope to avoid stack too deep errors
    //         (uint reserve0, uint reserve1,) = pair.getReserves();
    //         (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    //         amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
    //         amountOutput = SwappiLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
    //         }
    //         (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
    //         address to = i < path.length - 2 ? SwappiLibrary.pairFor(factory, output, path[i + 2]) : _to;
    //         pair.swap(amount0Out, amount1Out, to, new bytes(0));
    //     }
    // }
    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external virtual override ensure(deadline) {
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amountIn
    //     );
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }
    // function swapExactETHForTokensSupportingFeeOnTransferTokens(
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    //     external
    //     virtual
    //     override
    //     payable
    //     ensure(deadline)
    // {
    //     require(path[0] == WETH, 'SwappiRouter: INVALID_PATH');
    //     uint amountIn = msg.value;
    //     IWETH(WETH).deposit{value: amountIn}();
    //     assert(IWETH(WETH).transfer(SwappiLibrary.pairFor(factory, path[0], path[1]), amountIn));
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }
    // function swapExactTokensForETHSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // )
    //     external
    //     virtual
    //     override
    //     ensure(deadline)
    // {
    //     require(path[path.length - 1] == WETH, 'SwappiRouter: INVALID_PATH');
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, SwappiLibrary.pairFor(factory, path[0], path[1]), amountIn
    //     );
    //     _swapSupportingFeeOnTransferTokens(path, address(this));
    //     uint amountOut = IERC20(WETH).balanceOf(address(this));
    //     require(amountOut >= amountOutMin, 'SwappiRouter: INSUFFICIENT_OUTPUT_AMOUNT');
    //     IWETH(WETH).withdraw(amountOut);
    //     TransferHelper.safeTransferETH(to, amountOut);
    // }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB, uint256[2] memory normalizedWeights) public view virtual override returns (uint amountB) {
        return SwappiLibrary.quote(amountA, reserveA, reserveB, normalizedWeights);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut)
        public
        view
        virtual
        override
        returns (uint amountOut)
    {
        return SwappiLibrary.getAmountOut(amountIn, reserveIn, reserveOut, tokenIn, tokenOut, factory);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, address tokenIn, address tokenOut)
        public
        view
        virtual
        override
        returns (uint amountIn)
    {
        return SwappiLibrary.getAmountIn(amountOut, reserveIn, reserveOut, tokenIn, tokenOut, factory);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SwappiLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return SwappiLibrary.getAmountsIn(factory, amountOut, path);
    }
}
