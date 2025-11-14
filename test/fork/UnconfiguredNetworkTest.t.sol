// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeploySwapOperations} from "script/DeploySwapOperations.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract UnconfiguredNetworkTest is Test{
    DeploySwapOperations deployer;
    HelperConfig helperConfig;

    function setUp() public {
        vm.selectFork(vm.createFork(vm.envString("LINEA_SEPOLIA_RPC_URL")));
    }

    function testDeployOnUnconfiguredNetworkReverts() public {
        deployer = new DeploySwapOperations();
        vm.expectRevert();
        deployer.deploySwapOperations(makeAddr("owner"));

        helperConfig = new HelperConfig();
        vm.expectRevert(
            abi.encodeWithSelector(
                HelperConfig.HelperConfig__InvalidChainId.selector,
                block.chainid
            )
        );
        helperConfig.getConfigByChainId(block.chainid);
    }
}