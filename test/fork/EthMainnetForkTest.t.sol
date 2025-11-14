// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SwapProtocolBaseTest} from "test/unit/SwapProtocolBaseTest.t.sol";
import {ChainIds} from "script/HelperConfig.s.sol";


contract SwapProtocolMainnetForkTest is SwapProtocolBaseTest, ChainIds {
    uint256 ethMainnetForkId;

    function setUp() public override {
        ethMainnetForkId = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(ethMainnetForkId);
        super.setUp();
    }

    function testForkedEnvironmentWorks() external view {
        assertEq(block.chainid, MAINNET_ETH_CHAIN_ID);
    }
}