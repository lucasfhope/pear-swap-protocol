// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeploySwapOperations} from "script/DeploySwapOperations.s.sol";
import {ISwapOperations} from "src/interfaces/ISwapOperations.sol";
import {IHoldingVaultFactory} from "src/interfaces/IHoldingVaultFactory.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";

interface IOwnableMinimal {
    function owner() external view returns (address);
}

contract DeploySwapOperationsTest is Test {
    DeploySwapOperations deployer;
    ISwapOperations swapOperations;
    IHoldingVaultFactory holdingVaultFactory;
    IHoldingVault holdingVaultImplementation;
    IOwnableMinimal swapOperationsOwner;
    IOwnableMinimal holdingVaultFactoryOwner;

    address owner = makeAddr("owner");

    function setUp() external {
        deployer = new DeploySwapOperations();
        (address _swapOperations,) = deployer.run(owner);
        swapOperations = ISwapOperations(_swapOperations);
        holdingVaultFactory = IHoldingVaultFactory(swapOperations.getHoldingVaultFactory());
        holdingVaultImplementation = IHoldingVault(holdingVaultFactory.getImplementation());
        swapOperationsOwner = IOwnableMinimal(_swapOperations);
        holdingVaultFactoryOwner = IOwnableMinimal(address(holdingVaultFactory));
    }

    function testCanDeploySwapOperations() external view {
        assert(address(swapOperations) != address(0));
        assert(swapOperationsOwner.owner() == owner);
        assert(address(holdingVaultFactory) != address(0));
        assert(holdingVaultFactoryOwner.owner() == address(swapOperations));
        assert(address(holdingVaultFactory.getImplementation()) != address(0));
    }
}
