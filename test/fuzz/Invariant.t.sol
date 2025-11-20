// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import {DeploySwapOperations} from "script/DeploySwapOperations.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {SwapOperations} from "src/SwapOperations.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {Handler} from "test/fuzz/Handler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
    DeploySwapOperations deployer;
    SwapOperations swapOps;
    HelperConfig config;
    Handler handler;
    address[] allowedTokens;

    address owner = makeAddr("owner");

    function setUp() external {
        deployer = new DeploySwapOperations();
        (address _swapOpsAddr, address _configAddr) = deployer.run(owner);
        swapOps = SwapOperations(_swapOpsAddr);
        config = HelperConfig(_configAddr);

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        allowedTokens = new address[](4);
        allowedTokens[0] = networkConfig.weth;
        allowedTokens[1] = networkConfig.usdc;
        allowedTokens[2] = networkConfig.link;
        allowedTokens[3] = networkConfig.dai;

        handler = new Handler(swapOps, allowedTokens);
        targetContract(address(handler));
    }

    function invariant_vaultBalanceMatchesStatus() public view {
        address[] memory vaults = handler.getVaults();
        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = vaults[i];

            IHoldingVault.SwapStatus status = IHoldingVault(vault).getSwapStatus();
            address offerToken = IHoldingVault(vault).getOfferToken();
            uint256 offerAmount = IHoldingVault(vault).getAmountOffered();
            uint256 balance = IERC20(offerToken).balanceOf(vault);

            if (status == IHoldingVault.SwapStatus.Active) {
                assert(balance == offerAmount);
            } else {
                assert(balance == 0);
            }
        }
    }

    function invariant_vaultParametersAreValid() public view {
        address[] memory vaults = handler.getVaults();

        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = vaults[i];

            address offerToken = IHoldingVault(vault).getOfferToken();
            address requestToken = IHoldingVault(vault).getRequestedToken();
            uint256 offerAmount = IHoldingVault(vault).getAmountOffered();
            uint256 requestAmount = IHoldingVault(vault).getAmountRequested();

            assert(offerToken != requestToken);
            assert(offerAmount > 0);
            assert(requestAmount > 0);
        }
    }

    function invariant_swapOperationsHoldsNoTokens() public view {
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            uint256 bal = IERC20(allowedTokens[i]).balanceOf(address(swapOps));
            assert(bal == 0);
        }
    }

    function invariant_activeVaultTokensAreAllowed() public view {
        address[] memory vaults = handler.getVaults();

        for (uint256 i = 0; i < vaults.length; i++) {
            address vault = vaults[i];

            if (IHoldingVault(vault).getSwapStatus() == IHoldingVault.SwapStatus.Active) {
                address offerToken = IHoldingVault(vault).getOfferToken();
                address requestToken = IHoldingVault(vault).getRequestedToken();

                assert(swapOps.isAllowedToken(offerToken));
                assert(swapOps.isAllowedToken(requestToken));
            }
        }
    }
}
