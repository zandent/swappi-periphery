# Swappi Router

### Bsc-Test

The following assumes the use of `node@>=10`.

## Install Dependencies

`yarn`

## Compile Contracts

`yarn compile`

## Run Tests

`yarn test`

## Function description
### Add liquidity for two tokens
```solidity
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
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)
```
tokenA: token address

tokenB: token address. Note that tokenA must be less than tokenB

normalizedWeights: if the pair doesn't exist, the function will create the pair with the weight parameters. E.g [4e17, 6e17] means the ratio of tokenA and tokenB is 4:6. If the pair exists, the parameter is useless. It can be set at any value.

amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline: All parameters are the same as Swappi V1.

### Add liquidity for CFX and the other token
```solidity
function addLiquidityETH(
        address token,
        uint256[2] calldata normalizedWeights,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity)
```
normalizedWeights: normalizedWeights[0] is the weight of the smaller address.  normalizedWeights[1] is for the bigger one. I.e.
```python
if WCFX address < token:
    normalizedWeights[0] = weight of WCFX
    normalizedWeights[1] = weight of token
else:
    normalizedWeights[0] = weight of token
    normalizedWeights[1] = weight of WCFX
```
### Add liquidity with single token
```solidity
function addLiquidityForOneToken(
        address tokenA,
        address tokenB,
        uint liquidityDesired,
        uint tokenIndex,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)

function addLiquidityETHForOneToken(
        address token,
        uint liquidityDesired,
        uint tokenIndex,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity)
```
tokenIndex: 0 means to add liquidity for the token with smaller address. 1 means the larger address.
liquidityDesired: the liquidity to be needed
Note that tokenA must be less than tokenB.
### Remove liquidity for two tokens
```solidity
function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB)
```
Same as Swappi V1. Note that tokenA must be less than tokenB

### Remove liquidity for CFX and the other token
```solidity
function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH)
```

### Remove liquidity with single token
```solidity
function removeLiquidityForOneToken(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint tokenIndex
    ) public ensure(deadline) returns (uint amountA, uint amountB)

function removeLiquidityETHForOneToken(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint tokenIndex
    ) public ensure(deadline) returns (uint amountToken, uint amountETH)
```
tokenIndex: 0 means to get back the token with smaller address. 1 means the larger address.
liquidity: the liquidity to be burned
Note that tokenA must be less than tokenB.