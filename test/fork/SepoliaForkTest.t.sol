// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SwapProtocolBaseTest} from "test/unit/SwapProtocolBaseTest.t.sol";
import {ChainIds} from "script/HelperConfig.s.sol";

contract SwapProtocolSepoliaForkTest is SwapProtocolBaseTest, ChainIds {
    uint256 sepoliaForkId;

    function setUp() public override {
        sepoliaForkId = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(sepoliaForkId);
        super.setUp();
    }

    function testForkedEnvironment() external view {
        assertEq(block.chainid, SEPOLIA_ETH_CHAIN_ID);
    }
}
