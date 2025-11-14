// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ISwapOperations {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SwapOperations__TokenNotAllowed(address token);
    error SwapOperations__OfferAndRequestAmountsMustBeGreaterThanZero();
    error SwapOperations__VaultDidNotReceiveOfferTokens();
    error SwapOperations__NotCreatorOfSwapOffer();
    error SwapOperations__SwapOfferNotActive();
    error SwapOperations__SwapOfferDoesntExist();
    error SwapOperations__CantSwapSameToken();
    error SwapOperations__SwapOfferIsYourOwn();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Swap details used when creating an offer
     * @param offerToken The token being offered in the swap
     * @param requestToken The token being requested in the swap
     * @param offerAmount The amount of the offer token being offered
     * @param requestAmount The amount of the requested token being requested
     */
    struct SwapOffer {
        address offerToken;
        address requestToken;
        uint256 offerAmount;
        uint256 requestAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event SwapOfferCreated(
        address indexed creator,
        address indexed offerToken,
        address indexed requestToken,
        uint256 offerAmount,
        uint256 requestAmount,
        address holdingVault
    );
    event SwapOfferCompleted(address indexed holdingVault, address indexed acceptor);
    event SwapOfferCancelled(address indexed holdingVault);
    event AllowedTokenUpdated(address indexed token, bool isAllowed);
    

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /** 
     * @notice Creates a new swap offer and returns the created vault address
     * @param swapOffer Swap offer details
     * @return Address of the newly created holding vault
     */
    function createSwapOffer(SwapOffer memory swapOffer) external returns (address);

    /** 
     * @notice Cancels an active swap offer
     * @param vaultAddress Address of the holding vault representing the swap
     * @notice Callable by ownly the creator of the swap offer
     */
    function cancelSwapOffer(address vaultAddress) external;

    /**
     * @notice Allows caller to accept an active swap offer and complete the swap.
     * @param vaultAddress Address of the holding vault representing the swap
     * @notice Cannot be called by the creator of the swap offer
     */
    function acceptSwapOffer(address vaultAddress) external;

    /*//////////////////////////////////////////////////////////////
                             GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function isAllowedToken(address token) external view returns (bool allowed);
    function getHoldingVaultFactory() external view returns (address);
}

interface ISwapOperationsOwner {
    function updateAllowedToken(address token, bool isAllowed) external;
}
