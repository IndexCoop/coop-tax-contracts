// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract OwlNFT is ERC721, Ownable {

    enum OwlRank { BRONZE, SILVER, GOLD }

    uint256 currentId;
    mapping(uint256 => OwlRank) ranks;

    constructor() public ERC721("OwlNFT", "OWL") {}

    function batchMint(address[] memory _to, OwlRank[] memory _ranks) external {
        require(_to.length == _ranks.length, "length mismatch");

        for (uint256 i = 0; i < _to.length; i++) {
            _safeMint(_to[i], currentId);
            ranks[currentId] = _ranks[i];
            currentId = currentId.add(1);
        }
    }

    function getVotes(uint256 _id) external view returns (uint256) {

        require(_id < currentId, "invalid id");

        OwlRank rank = ranks[_id];

        if (rank == OwlRank.BRONZE) return 50 ether;
        if (rank == OwlRank.SILVER) return 75 ether;
        if (rank == OwlRank.GOLD) return 100 ether;

        return 0;
    }
}