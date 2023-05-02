pragma solidity >=0.5.0;

interface ISwappiFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event feeToChanged(address feeTo);
    event feeToSetterChanged(address feeToSetter);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, uint256[2] calldata normalizedWeights) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}
