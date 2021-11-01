// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import { GIMExtension } from "indexcoop/contracts/adapters/GIMExtension.sol";
import { IBaseManager } from "indexcoop/contracts/interfaces/IBaseManager.sol";
import { IGeneralIndexModule } from "indexcoop/contracts/interfaces/IGeneralIndexModule.sol";

import { OwlNFT } from "./OwlNFT.sol";

contract ApeRebalanceExtension is GIMExtension {

    uint256 public epochLength;
    uint256 public  currentEpochStart;
    
    mapping(address => uint256) public lastEpochVoted;
    mapping(address => uint256) public votes;
    address[] public possibleComponents;

    uint256 public immutable maxComponents;

    OwlNFT public owlNft;

    constructor(
        IBaseManager _manager,
        IGeneralIndexModule _gim,
        OwlNFT _owlNft,
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
    }
 
    function vote(address[] memory _components, uint256[] memory _votes) external {
        require(_components.length == _votes.length, "length mismatch");

        if (_isEpochOver()) {
            currentEpochStart = currentEpochStart.add(epochLength);

            for (uint256 i = 0; i < possibleComponents.length; i++) {
                votes[possibleComponents[i]] = 0;
            }
            delete possibleComponents;
        }

        require(lastEpochVoted[msg.sender] != currentEpochStart, "already voted");
        lastEpochVoted[msg.sender] = currentEpochStart;

        uint256 sumVotes;
        for (uint256 i = 0; i < _components.length; i++) {
            require(_votes[i] != 0, "no zero votes allowed");
            if (votes[_components[i]] == 0) {
                possibleComponents.push(_components[i]);
            }
            votes[_components[i]] = votes[_components[i]].add(_votes[i]);
            sumVotes = sumVotes.add(_votes[i]);
        }

        require(sumVotes <= _getVotes(msg.sender), "too many votes used");
    }

    function startRebalance() external onlyOperator {
        // forgive me father for I have sinned with this selection sort
        address[] memory possibleLeft = possibleComponents;
        address[] memory finalComponents = new address[](maxComponents);
        for (uint256 i = 0; i < maxComponents; i++) {
            uint256 max;
            uint256 maxIndex;
            for (uint256 j = 0; j < possibleLeft.length; j++) {
                uint256 currentVotes = votes[possibleLeft[j]];
                if (currentVotes > max) {
                    max = currentVotes;
                    maxIndex = j;
                }
            }
            finalComponents[i] = possibleLeft[maxIndex];
            (possibleLeft,) = possibleLeft.pop(maxIndex);
        }

        uint256[] memory finalUnits = new uint256[](maxComponents);
        for (uint256 i = 0; i < maxComponents; i++) {
            finalUnits[i] = votes[finalComponents[i]];
        }

        (
            address[] memory newComponents,
            uint256[] memory newComponentsTargetUnits,
            uint256[] memory oldComponentsTargetUnits
        ) = _sortNewAndOldComponents(finalComponents, finalUnits);

        // since we fix the position multiplier to 1 we cannot have a streaming fee in any set that uses this
        _startRebalance(newComponents, newComponentsTargetUnits, oldComponentsTargetUnits, 1 ether);
    }

    // TODO: fix override
    function startRebalanceWithUnitsOverride(
        address[] memory /* _components */,
        uint256[] memory /* _targetUnits */,
        uint256 /* _positionMultiplier */
    )
        external
        pure
    {
        revert("only democratically elected shitcoins allowed");
    }

    function _getVotes(address _voter) internal view returns (uint256) {
        uint256 bal = owlNft.balanceOf(_voter);
        
        uint256 totalVotes;
        for (uint256 i = 0; i < bal; i++) {
            uint256 id = owlNft.tokenOfOwnerByIndex(_voter, i);
            totalVotes = totalVotes.add(owlNft.getVotes(id));
        }

        return totalVotes;
    }

    function _isEpochOver() internal view returns (bool) {
        return block.timestamp >= currentEpochStart.add(epochLength);
    }
}