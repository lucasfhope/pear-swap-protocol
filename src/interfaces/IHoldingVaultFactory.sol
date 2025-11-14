// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHoldingVaultFactory {
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice all external functions should be called only by the owner (SwapOperations)

    /**
     * @notice Creates a clone of the holding vault implementation for a swap offer
     * @param creator The address of the creator of the vault
     * @param offerToken The address of the token being offered
     * @param requestToken The address of the token being requested
     * @param offerAmount The amount of the offer token
     * @param requestAmount The amount of the request token
     * @return The address of the newly created holding vault
     */
    function createHoldingVaultForSwapOffer(
        address creator,
        address offerToken,
        address requestToken,
        uint256 offerAmount,
        uint256 requestAmount
    ) external returns (address); 

    /// @notice Calls the vault to complete the swap on behalf of the acceptor
    function completeHoldingVaultSwap(address vaultAddress, address acceptor) external;

    /// @notice Calls the vault to cancel the swap
    function setHoldingVaultAsCanceled(address vaultAddress) external;

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getCreatorOfVault(address vault) external view returns (address);
    function getImplementation() external view returns (address);
}