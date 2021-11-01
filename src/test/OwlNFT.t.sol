// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "ds-test/test.sol";

import { OwlNFT } from "../ape-together/OwlNFT.sol";

contract OwlNFTTest is DSTest {
    OwlNFT nft;

    function setUp() public {
        nft = new OwlNFT();
    }

    function test_batchMint() public {
        address[] memory to = new address[](2);
        OwlNFT.OwlRank[] memory ranks = new OwlNFT.OwlRank[](2);

        to[0] = address(0x1);
        to[1] = address(0x2);

        ranks[0] = OwlNFT.OwlRank.GOLD;
        ranks[1] = OwlNFT.OwlRank.SILVER;

        nft.batchMint(to, ranks);

        assertEq(nft.balanceOf(address(0x1)), 1);
        assertEq(nft.balanceOf(address(0x2)), 1);
    }

    function test_getVotes() public {
        address[] memory to = new address[](3);
        OwlNFT.OwlRank[] memory ranks = new OwlNFT.OwlRank[](3);

        to[0] = address(0x1);
        to[1] = address(0x2);
        to[2] = address(0x3);

        ranks[0] = OwlNFT.OwlRank.GOLD;
        ranks[1] = OwlNFT.OwlRank.SILVER;
        ranks[2] = OwlNFT.OwlRank.BRONZE;

        nft.batchMint(to, ranks);

        assertEq(nft.getVotes(0), 100);
        assertEq(nft.getVotes(1), 75);
        assertEq(nft.getVotes(2), 50);

        // should revert
        (bool success, ) = address(nft).call(abi.encodeWithSelector(nft.getVotes.selector, 3));
        assertTrue(!success);
    }
}