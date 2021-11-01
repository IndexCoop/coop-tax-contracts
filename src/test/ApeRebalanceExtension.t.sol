// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import "ds-test/test.sol";

import { BaseManagerV2 } from "indexcoop/contracts/manager/BaseManagerV2.sol";
import { StandardTokenMock } from "indexcoop/contracts/mocks/StandardTokenMock.sol";

import { ApeRebalanceExtension } from "../ape-together/ApeRebalanceExtension.sol";
import { OwlNFT } from "../ape-together/OwlNFT.sol";
import { SetFixture } from "../utils/SetFixture.sol";

import { IBaseManager } from "indexcoop/contracts/interfaces/IBaseManager.sol";
import { ISetToken } from "indexcoop/contracts/interfaces/ISetToken.sol";
import { IGeneralIndexModule } from "indexcoop/contracts/interfaces/IGeneralIndexModule.sol";
import { IHevm } from "../utils/IHevm.sol";


contract Voter {

    ApeRebalanceExtension extension;

    constructor(ApeRebalanceExtension _extension) public {
        extension = _extension;
    }

    function vote(address[] memory _components, uint256[] memory _votes) external {
        extension.vote(_components, _votes);
    }

    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    )
        external
        pure
        returns (bytes4)
    {
        return bytes4(0x150b7a02);
    }
}

contract ApeRebalanceExtensionTest is DSTest {

    IHevm constant hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    ApeRebalanceExtension apeExtension;
    OwlNFT nft;

    Voter voterA;
    Voter voterB;
    Voter voterC;

    SetFixture setFixture;
    ISetToken setToken;
    BaseManagerV2 baseManager;
    StandardTokenMock dai;

    function setUp() public {

        hevm.warp(10000);

        setFixture = new SetFixture(address(this));

        dai = new StandardTokenMock(address(this), 10000 ether, "DAI", "DAI", 18);

        address[] memory components = new address[](1);
        components[0] = address(dai);
        int256[] memory units = new int256[](1);
        units[0] = 1 ether;

        setToken = ISetToken(setFixture.createSetToken(components, units, address(this)));
        baseManager = new BaseManagerV2(setToken, address(this), address(this));
        setToken.setManager(address(baseManager));
        baseManager.authorizeInitialization();

        nft = new OwlNFT();

        apeExtension = new ApeRebalanceExtension(
            IBaseManager(address(baseManager)),
            IGeneralIndexModule(address(setFixture.generalIndexModule())),
            nft,
            block.timestamp,
            1000,
            10
        );

        // setup voters
        voterA = new Voter(apeExtension);
        voterB = new Voter(apeExtension);
        voterC = new Voter(apeExtension);

        address[] memory to = new address[](2);
        OwlNFT.OwlRank[] memory ranks = new OwlNFT.OwlRank[](2);

        to[0] = address(voterA);
        to[1] = address(voterB);

        ranks[0] = OwlNFT.OwlRank.GOLD;
        ranks[1] = OwlNFT.OwlRank.SILVER;

        nft.batchMint(to, ranks);
    }

    function test_vote() public {
        address[] memory components = new address[](2);
        components[0] = address(0x1);
        components[1] = address(0x2);

        uint256[] memory votes = new uint256[](2);
        votes[0] = 75 ether;
        votes[1] = 25 ether;

        voterA.vote(components, votes);

        assertEq(apeExtension.votes(components[0]), 75 ether);
        assertEq(apeExtension.votes(components[1]), 25 ether);
    }

    function test_voteMultipleVoters() public {
        address[] memory components = new address[](2);
        components[0] = address(0x1);
        components[1] = address(0x2);

        uint256[] memory votes = new uint256[](2);
        votes[0] = 20 ether;
        votes[1] = 30 ether;

        voterA.vote(components, votes);
        voterB.vote(components, votes);

        assertEq(apeExtension.votes(components[0]), 40 ether);
        assertEq(apeExtension.votes(components[1]), 60 ether);
    }

    function testFail_voteDouble() public {
        address[] memory components = new address[](2);
        components[0] = address(0x1);
        components[1] = address(0x2);

        uint256[] memory votes = new uint256[](2);
        votes[0] = 20 ether;
        votes[1] = 30 ether;

        voterA.vote(components, votes);
        voterA.vote(components, votes);
    }

    function testFail_voteZeroVotes() public {
        address[] memory components = new address[](2);
        components[0] = address(0x1);
        components[1] = address(0x2);

        uint256[] memory votes = new uint256[](2);
        votes[0] = 20 ether;
        votes[1] = 30 ether;

        voterC.vote(components, votes);
    }

    function testFail_voteToManyVotes() public {
        address[] memory components = new address[](2);
        components[0] = address(0x1);
        components[1] = address(0x2);

        uint256[] memory votes = new uint256[](2);
        votes[0] = 90 ether;
        votes[1] = 30 ether;

        voterA.vote(components, votes);
    }
}