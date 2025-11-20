// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SwapOperations} from "src/SwapOperations.sol";
import {ISwapOperations} from "src/interfaces/ISwapOperations.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Handler is Test {
    SwapOperations swapOps;
    address[] allowedTokens;

    address[] users;
    address[] vaults;
    mapping(address => address) vaultToUser;

    constructor(SwapOperations _swapOps, address[] memory _allowedTokens) {
        swapOps = _swapOps;
        allowedTokens = _allowedTokens;

        for (uint256 i = 0; i < 10; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            users.push(user);
            vm.deal(user, 10 ether);
        }
    }

    function createSwapOffer(uint256 _userSeed, uint256 _tokenSeed, uint256 _offerAmount, uint256 _requestAmount)
        external
    {
        (ERC20Mock offerToken, ERC20Mock requestToken) = _getTwoRandomAllowedTokens(_tokenSeed);

        address user = getRandomUser(_userSeed);

        uint256 offerDecimals = offerToken.decimals();
        uint256 requestDecimals = requestToken.decimals();
        uint256 offerAmount = bound(_offerAmount, 1, 10000) * (10 ** (offerDecimals + 2));
        uint256 requestAmount = bound(_requestAmount, 1, 10000) * (10 ** (requestDecimals + 2));

        vm.startPrank(user);
        offerToken.mint(user, offerAmount);
        offerToken.approve(address(swapOps), offerAmount);
        address vault = swapOps.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(offerToken),
                requestToken: address(requestToken),
                offerAmount: offerAmount,
                requestAmount: requestAmount
            })
        );
        vm.stopPrank();

        vaults.push(vault);
        vaultToUser[vault] = user;
    }

    function cancelSwapOffer(uint256 _vaultSeed) external {
        address vault = _getRandomActiveVault(_vaultSeed);
        if (vault == address(0)) {
            return;
        }

        address user = vaultToUser[vault];

        vm.prank(user);
        swapOps.cancelSwapOffer(vault);
    }

    function acceptSwapOffer(uint256 _vaultSeed, uint256 _userSeed) external {
        address vault = _getRandomActiveVault(_vaultSeed);
        if (vault == address(0)) {
            return;
        }

        address user = getRandomOtherUser(_userSeed, vaultToUser[vault]);
        address requestToken = IHoldingVault(vault).getRequestedToken();
        uint256 requestAmount = IHoldingVault(vault).getAmountRequested();

        vm.startPrank(user);
        ERC20Mock(requestToken).mint(user, requestAmount);
        ERC20Mock(requestToken).approve(address(swapOps), requestAmount);
        swapOps.acceptSwapOffer(vault);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getTwoRandomAllowedTokens(uint256 seed) internal view returns (ERC20Mock, ERC20Mock) {
        uint256 len = allowedTokens.length;
        if (allowedTokens.length < 2) {
            revert("Not enough allowed tokens");
        }

        uint256 i1 = seed % len;
        uint256 i2 = (seed / len) % (len - 1);
        if (i2 >= i1) {
            i2++;
        }

        return (ERC20Mock(allowedTokens[i1]), ERC20Mock(allowedTokens[i2]));
    }

    function _getRandomActiveVault(uint256 seed) internal view returns (address) {
        uint256 len = vaults.length;
        if (len == 0) return address(0);

        uint256 start = seed % len;
        for (uint256 i = 0; i < len; i++) {
            uint256 idx = (start + i) % len;
            address candidate = vaults[idx];

            if (IHoldingVault(candidate).getSwapStatus() == IHoldingVault.SwapStatus.Active) {
                return candidate;
            }
        }
        return address(0);
    }

    function getRandomUser(uint256 seed) internal view returns (address) {
        uint256 len = users.length;
        if (len == 0) {
            revert("No users");
        }
        uint256 idx = seed % len;
        return users[idx];
    }

    function getRandomOtherUser(uint256 seed, address exclude) internal view returns (address) {
        uint256 len = users.length;
        if (len < 2) {
            revert("Not enough users");
        }
        uint256 start = seed % len;
        for (uint256 i = 0; i < len; i++) {
            uint256 idx = (start + i) % len;
            address candidate = users[idx];
            if (candidate != exclude) {
                return candidate;
            }
        }
        revert("No other user found");
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getVaults() external view returns (address[] memory) {
        return vaults;
    }
}
