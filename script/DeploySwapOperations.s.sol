// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {SwapOperations} from "src/SwapOperations.sol";

contract DeploySwapOperations is Script {
    function run(address owner) external returns (address swapOperations, address helperConfig) {
        vm.startBroadcast();
        (swapOperations, helperConfig) = deploySwapOperations(owner);
        vm.stopBroadcast();
    }

    function deploySwapOperations(address owner) public returns (address, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address[] memory allowedTokens = new address[](4);
        allowedTokens[0] = networkConfig.weth;
        allowedTokens[1] = networkConfig.usdc;
        allowedTokens[2] = networkConfig.link;
        allowedTokens[3] = networkConfig.dai;
        SwapOperations swapOperations = new SwapOperations(owner, allowedTokens);
        return (address(swapOperations), address(helperConfig));
    }
}
