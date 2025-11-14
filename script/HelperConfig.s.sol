// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {LinkTokenMock} from "test/mocks/LinkTokenMock.sol";
import {USDCMock} from "test/mocks/USDCMock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

abstract contract ChainIds {
    uint256 public constant MAINNET_ETH_CHAIN_ID = 1;
    uint256 public constant SEPOLIA_ETH_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_ANVIL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, ChainIds {
    error HelperConfig__InvalidChainId(uint256 chainId);

    struct NetworkConfig {
        address weth;
        address usdc;
        address link;
        address dai;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_ETH_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[MAINNET_ETH_CHAIN_ID] = getEthMainnetConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].weth != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_ANVIL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId(chainId);
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
            usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            dai: 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6
        });
    }

    function getEthMainnetConfig() private pure returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            dai: 0x6B175474E89094C44Da98b954EedeAC495271d0F
        });
    }

    function getOrCreateAnvilEthConfig() private returns (NetworkConfig memory) {
        if (localNetworkConfig.weth != address(0)) {
            return localNetworkConfig;
        }

        LinkTokenMock link = new LinkTokenMock();
        USDCMock usdc = new USDCMock();
        ERC20Mock weth = new ERC20Mock("Wrapped Ether", "WETH");
        ERC20Mock dai = new ERC20Mock("Dai Stablecoin", "DAI");

        localNetworkConfig =
            NetworkConfig({weth: address(weth), usdc: address(usdc), link: address(link), dai: address(dai)});

        return localNetworkConfig;
    }
}
