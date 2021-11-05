// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "indexcoop/contracts/adapters/GIMExtension.sol";
import "indexcoop/contracts/interfaces/IBaseManager.sol";
import "indexcoop/contracts/interfaces/IGeneralIndexModule.sol";
import "indexcoop/contracts/lib/PreciseUnitMath.sol";

import "setprotocol/contracts/interfaces/external/IUniswapV2Router.sol";
import "setprotocol/contracts/interfaces/external/IUniswapV2Factory.sol";

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./OwlNFT.sol";

/**
 * @title ApeRebalanceExtension
 * @author Index Coop
 *
 * Rebalance extension that allows NFT holders to vote on token allocations. Rebalancing is still not
 * fully trustless, as the operator must act as a price oracle for the tokens involved in the rebalance
 * and set the trade data. However, a malicious operator can not introduce new tokens into the rebalance,
 * but can influence the weighting by modifying the inputted price.
 */
contract ApeRebalanceExtension is GIMExtension {
    using PreciseUnitMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    /* ========== State Variables ======== */

    address public engineer;

    uint256 public epochLength;
    uint256 public  currentEpochStart;
    
    mapping(uint256 => uint256) public lastEpochVoted;
    mapping(address => uint256) public votes;

    address[] public possibleComponents;
    uint256 public immutable maxComponents;

    OwlNFT public owlNft;

    IUniswapV2Router public sushiRouter;
    IUniswapV2Router public quickRouter;
    IERC20 weth;
    uint256 public minWethLiquidity;

    /* ========== Constructor ========== */

    /**
     * Sets state variables.
     *
     * @param _manager          address of manager contract
     * @param _gim              address of Set Protocol GeneralIndexModule
     * @param _owlNft           address of OwlNFT contract
     * @param _startTime        timestamp for the start of the first voting period
     * @param _epochLength      length of a voting period (in seconds)
     * @param _maxComponents    maximum number of components in the set
     */
    constructor(
        IBaseManager _manager,
        IGeneralIndexModule _gim,
        OwlNFT _owlNft,
        IUniswapV2Router _sushiRouter,
        IUniswapV2Router _quickRouter,
        IERC20 _weth,
        uint256 _minWethLiquidity,
        uint256 _startTime,
        uint256 _epochLength,
        uint256 _maxComponents
    )
        public 
        GIMExtension(_manager, _gim)
    {
        owlNft = _owlNft;
        currentEpochStart = _startTime;
        epochLength = _epochLength;
        maxComponents = _maxComponents;
        sushiRouter = _sushiRouter;
        quickRouter = _quickRouter;
        weth = _weth;
        minWethLiquidity = _minWethLiquidity;
    }

    /* ======== External Functions ======== */
 
    /**
     * Submits a vote for an OwlNFT holder. Sum of all votes must not exceed the total
     * votes that the NFT holder has alloted to them. This value can be fetched by calling
     * getVotes on the NFT contract.
     *
     * @param _components   array of components that the NFT holder wants added to the index
     * @param _votes        array of number of votes allocated to each of the components
     */
    function vote(address[] memory _components, uint256[] memory _votes) external {
        require(_components.length == _votes.length, "length mismatch");
        require(!_isEpochOver(), "voting period ended");

        uint256 sumVotes;
        for (uint256 i = 0; i < _components.length; i++) {
            require(_votes[i] != 0, "no zero votes allowed");
            require(_getBestWethLiquidityAmount(_components[i]) >= minWethLiquidity, "not enough liquidity");

            if (votes[_components[i]] == 0) {
                possibleComponents.push(_components[i]);
            }
            votes[_components[i]] = votes[_components[i]].add(_votes[i]);
            sumVotes = sumVotes.add(_votes[i]);
        }

        require(sumVotes <= _getVotes(msg.sender), "too many votes used");
    }

    /**
     * ONLY OPERATOR: Starts the rebalance process. Operator must supply the prices for the components
     * being rebalances. If the component list does not match the components voted on by the OwlNFT holder
     * this function will revert.
     *
     * @param _setValue         Approximate USD value of the index
     * @param _components       Component list. Must match the compoennts voted on by OwlNFT holders
     * @param _componentPrices  Component prices of each component in the _component list.
     */
    function startRebalance(
        uint256 _setValue,
        address[] memory _components,
        uint256[] memory _componentPrices
    ) external onlyOperator {

        (address[] memory finalComponents, uint256[] memory weights) = _getWeights();

        // set next epoch time
        currentEpochStart = block.timestamp;
        
        // if no votes were submitted epoch rebalance is skipped
        if (finalComponents.length == 0) return;

        require(_components.length == finalComponents.length, "length mismatch");
        require(_components.length == _componentPrices.length, "length mismatch");

        uint256[] memory units = new uint256[](_components.length);
        for (uint256 i = 0; i < _components.length; i++) {
            require(finalComponents[i] == _components[i], "component mismatch");

            // (weight * total) / price
            units[i] = _setValue.preciseMul(weights[i]).preciseDiv(_componentPrices[i]);
        }

        address[] memory currentComponents = setToken.getComponents();
        address[] memory removedComponents = new address[](currentComponents.length);
        uint256 numRemoved;
        for (uint256 i = 0; i < currentComponents.length; i++) {
            if (!finalComponents.contains(currentComponents[i])) {
                removedComponents[numRemoved] = currentComponents[i];
                numRemoved = numRemoved.add(1);
            }
        }

        uint256 finalLength = finalComponents.length.add(numRemoved);
        address[] memory finalComponentsComplete = new address[](finalLength);
        uint256[] memory finalUnitsComplete = new uint256[](finalLength);
        for (uint256 i = 0; i < finalComponents.length; i++) {
            finalComponentsComplete[i] = finalComponents[i];
            finalUnitsComplete[i] = units[i];
        }
        for (uint256 i = finalComponents.length; i < finalLength; i++) {
            finalComponentsComplete[i] = removedComponents[i.sub(finalComponents.length)];
        }
        

        (
            address[] memory newComponents,
            uint256[] memory newComponentsTargetUnits,
            uint256[] memory oldComponentsTargetUnits
        ) = _sortNewAndOldComponents(finalComponentsComplete, finalUnitsComplete);

        // since we fix the position multiplier to 1 we cannot have a streaming fee in any set that uses this
        _startRebalance(newComponents, newComponentsTargetUnits, oldComponentsTargetUnits, 1 ether);

        // clear out votes 
        for (uint256 i = 0; i < possibleComponents.length; i++) {
            votes[possibleComponents[i]] = 0;
        }
        delete possibleComponents;
    }

    /**
     * Overrides the original rebalance function from GIMExtension. Always reverts.
     */
    function startRebalanceWithUnits(
        address[] memory /* _components */,
        uint256[] memory /* _targetUnits */,
        uint256 /* _positionMultiplier */
    )
        external
        override
    {
        revert("only democratically elected shitcoins allowed");
    }

    /**
     * Fetches the current top voted components and weights. When the rebalance begins,
     * it will set the weights to be identical to the weights given by this function. The
     * weights are measured as the percentage of the toal index value, not the unit amounts.
     *
     * @return addres[]     top voted on components
     * @return uint256[]    components weights (not units) as per the vote
     */
    function getWeights() external view returns (address[] memory, uint256[] memory) {
        return _getWeights();
    }

    function isTokenLiquid(address _token) external view returns (bool) {
        return _getBestWethLiquidityAmount(_token) >= minWethLiquidity;
    }

    function getTokenPrice(address _token) external view returns (uint256) {
        return _getTokenPrice(_token);
    }

    function getSetPrice() external view returns (uint256) {
        address[] memory components = setToken.getComponents();

        uint256 sumValue;
        for (uint256 i = 0; i < components.length; i++) {
            uint256 units = setToken.getDefaultPositionRealUnit(components[i]).toUint256();
            uint256 value = _getTokenPrice(components[i]).preciseMul(units);
            sumValue = sumValue.add(value);
        }

        return sumValue;
    }

    function getRebalancePrices() external view returns (address[] memory components, uint256[] memory prices){
        (components,) = _getWeights();

        prices = new uint256[](components.length);
        for (uint256 i = 0; i < components.length; i++) {
            prices[i] = _getTokenPrice(components[i]);
        }
    }

    /* ========= Internal Functions ========== */

    /**
     * Fetches the total number of votes of a user. This function allows for an address to
     * hold multiple OwlNFTs. This will update the lastEpochVoted for each nft held by the voter.
     * If any nft has already been used to vote during this epoch, then it will revert.
     *
     * @param _voter        address of voter to check votes for
     * @return uint256      number of votes that the address has
     */
    function _getVotes(address _voter) internal returns (uint256) {
        uint256 bal = owlNft.balanceOf(_voter);
        
        uint256 totalVotes;
        for (uint256 i = 0; i < bal; i++) {
            uint256 id = owlNft.tokenOfOwnerByIndex(_voter, i);

            require(lastEpochVoted[id] != currentEpochStart, "already voted");
            lastEpochVoted[id] = currentEpochStart;

            totalVotes = totalVotes.add(owlNft.getVotes(id));
        }

        return totalVotes;
    }

    /**
     * Checks whether the current epoch has ended.
     *
     * @return bool     whether current epoch has ended
     */
    function _isEpochOver() internal view returns (bool) {
        return block.timestamp >= currentEpochStart.add(epochLength);
    }

    /**
     * Fetches the current top voted components and weights. When the rebalance begins,
     * it will set the weights to be identical to the weights given by this function. The
     * weights are measured as the percentage of the toal index value, not the unit amounts.
     *
     * @return components   top voted on components
     * @return weights      components weights (not units) as per the vote
     */
    function _getWeights() internal view returns (address[] memory components, uint256[] memory weights) {
        
        address[] memory possibleLeft = possibleComponents;
        uint256 numComponents = Math.min(maxComponents, possibleComponents.length);
        components = new address[](numComponents);

        // forgive me father for I have sinned with this selection sort
        for (uint256 i = 0; i < numComponents; i++) {
            uint256 max;
            uint256 maxIndex;
            for (uint256 j = 0; j < possibleLeft.length; j++) {
                uint256 currentVotes = votes[possibleLeft[j]];
                if (currentVotes > max) {
                    max = currentVotes;
                    maxIndex = j;
                }
            }
            components[i] = possibleLeft[maxIndex];
            (possibleLeft,) = possibleLeft.pop(maxIndex);
        }

        uint256[] memory finalVotes = new uint256[](numComponents);
        uint256 sumVotes;
        for (uint256 i = 0; i < numComponents; i++) {
            uint256 currentVotes = votes[components[i]];
            finalVotes[i] = currentVotes;
            sumVotes = sumVotes.add(currentVotes);
        }

        weights = new uint256[](numComponents);
        for (uint256 i = 0; i < numComponents; i++) {
            weights[i] = finalVotes[i].preciseDiv(sumVotes);
        }
    }

    function _getBestRouter(address _token) internal view returns (IUniswapV2Router) {
        uint256 sushiWethLiq = _getWethLiquidity(_token, sushiRouter);
        uint256 quickWethLiq = _getWethLiquidity(_token, quickRouter);

        return sushiWethLiq > quickWethLiq ? sushiRouter : quickRouter;
    }

    function _getBestWethLiquidityAmount(address _token) internal view returns (uint256) {
        uint256 sushiWethLiq = _getWethLiquidity(_token, sushiRouter);
        uint256 quickWethLiq = _getWethLiquidity(_token, quickRouter);

        return Math.max(sushiWethLiq, quickWethLiq);
    }

    function _getWethLiquidity(address _token, IUniswapV2Router _router) internal view returns (uint256) {
        address pair = IUniswapV2Factory(_router.factory()).getPair(address(weth), _token);
        return weth.balanceOf(pair);
    }

    function _getTokenPrice(address _token) internal view returns (uint256) {
        IUniswapV2Router router = _getBestRouter(_token);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = _token;
        
        return uint(1).preciseDiv(router.getAmountsOut(1 ether, path)[1]);
    }
}