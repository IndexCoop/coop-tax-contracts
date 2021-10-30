// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

import { Controller } from "setprotocol/contracts/protocol/Controller.sol";
import { GeneralIndexModule } from "setprotocol/contracts/protocol/modules/GeneralIndexModule.sol";
import { IntegrationRegistry } from "setprotocol/contracts/protocol/IntegrationRegistry.sol";
import { BasicIssuanceModule } from "setprotocol/contracts/protocol/modules/BasicIssuanceModule.sol";
import { SetTokenCreator } from "setprotocol/contracts/protocol/SetTokenCreator.sol";

import { WETH9 } from "./WETH9.sol";

import { IController } from "setprotocol/contracts/interfaces/IController.sol";
import { IWETH } from "setprotocol/contracts/interfaces/external/IWETH.sol";

contract SetFixture {

    Controller public controller;
    IntegrationRegistry public integrationRegistry;
    SetTokenCreator public setTokenCreator;

    BasicIssuanceModule public basicIssuanceModule;
    GeneralIndexModule public generalIndexModule;

    WETH9 public weth;

    constructor(address _owner) public {
        weth = new WETH9();
        controller = new Controller(_owner);

        IWETH wethInterface = IWETH(address(weth));
        IController controllerInterface = IController(address(controller));

        integrationRegistry = new IntegrationRegistry(controllerInterface);
        integrationRegistry.transferOwnership(_owner);
        setTokenCreator = new SetTokenCreator(controllerInterface);

        basicIssuanceModule = new BasicIssuanceModule(controllerInterface);
        generalIndexModule = new GeneralIndexModule(controllerInterface, wethInterface);

        address[] memory factories = new address[](1);
        address[] memory modules = new address[](2);
        address[] memory resources = new address[](1);
        uint256[] memory resourceIds = new uint256[](1);

        factories[0] = address(setTokenCreator);
        modules[0] = address(generalIndexModule);
        modules[1] = address(basicIssuanceModule);
        resources[0] = address(integrationRegistry);
        resourceIds[0] = 0;

        controller.initialize(factories, modules, resources, resourceIds);
    }
}