// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {HoldingVault} from "src/HoldingVault.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HoldingVaultFactory is Ownable {
    address private immutable i_implementation;

    constructor() Ownable(msg.sender) {
        i_implementation = address(new HoldingVault(address(this)));
    }

    /*/////////////////////////////////////////////////////////////////////////
        EXTERNAL FUNCTIONS - SHOULD ONLY BE CALLED BY SWAP OPERATIONS (OWNER)
    //////////////////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a clone of the holding vault implementation for a swap offer
     * @param creator The address of the creator of the vault
     * @param offerToken The address of the token being offered
     * @param requestToken The address of the token being requested
     * @param offerAmount The amount of the offer token
     * @param requestAmount The amount of the request token
     * @return clonedHoldingVault The address of the newly created holding vault
     */
    function createHoldingVaultForSwapOffer(
        address creator,
        address offerToken,
        address requestToken,
        uint256 offerAmount,
        uint256 requestAmount
    ) external onlyOwner returns (address clonedHoldingVault) {
        clonedHoldingVault = Clones.clone(i_implementation);
        IHoldingVault(clonedHoldingVault)
            .init(creator, IERC20(offerToken), IERC20(requestToken), offerAmount, requestAmount);
    }

    /// @notice Calls the vault to complete the swap on behalf of the acceptor
    function completeHoldingVaultSwap(address vaultAddress, address acceptor) external onlyOwner {
        IHoldingVault(vaultAddress).completeSwapOffer(acceptor);
    }

    /// @notice Calls the vault to cancel the swap
    function setHoldingVaultAsCanceled(address vaultAddress) external onlyOwner {
        IHoldingVault(vaultAddress).swapOfferCancelled();
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getCreatorOfVault(address vault) external view returns (address) {
        return IHoldingVault(vault).getCreator();
    }

    function getImplementation() external view returns (address) {
        return i_implementation;
    }
}
