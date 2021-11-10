// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title OwlNFT
/// @author ncitron
/// @notice NFT contract for tracking voting weights of Index Coop contibutors for
/// rebalancing with the ApeRebalanceExtension. Each NFT is assinged a rank of either
/// gold, silver, or bronze, which correlated to the number of votes assigned to the holder
contract OwlNFT is ERC721, Ownable {

    enum OwlRank { BRONZE, SILVER, GOLD }

    uint256 currentId;
    mapping(uint256 => OwlRank) ranks;

    
    /// @notice Creates the OwlNFT
    constructor() public ERC721("OwlNFT", "OWL") {}

    /// @notice Batch mints NFTs
    /// @dev Only callable by owner
    /// @param _to Array of addresses to mint to
    /// @param _ranks Owl ranks for each of the NFTs
    function batchMint(address[] memory _to, OwlRank[] memory _ranks) external onlyOwner {
        require(_to.length == _ranks.length, "length mismatch");

        for (uint256 i = 0; i < _to.length; i++) {
            _safeMint(_to[i], currentId);
            ranks[currentId] = _ranks[i];
            currentId = currentId.add(1);
        }
    }

    /// @notice Gets the votes for the NFT. Gold owls get 100 votes, solver 75, and bronze 50.
    /// @param _id NFT id
    /// @return Number of votes for the id
    function getVotes(uint256 _id) external view returns (uint256) {

        require(_id < currentId, "invalid id");

        OwlRank rank = ranks[_id];

        if (rank == OwlRank.BRONZE) return 50 ether;
        if (rank == OwlRank.SILVER) return 75 ether;
        if (rank == OwlRank.GOLD) return 100 ether;
    }
}