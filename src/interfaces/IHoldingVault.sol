// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHoldingVault {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/
    error HoldingVault__AlreadyInitialized();
    error HoldingVault__NotCreator();
    error HoldingVault__OnlyFactoryCanExecute();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    enum SwapStatus {
        Active,
        Completed,
        Cancelled
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @dev All external functions should be called only by HoldingVaultFactory

    /**
     * @notice Initialize a freshly-deployed clone.
     * @param _creator The address of the swap offer creator
     * @param _offerToken The token being offered in the swap
     * @param _requestedToken The token being requested in the swap
     * @param _amountOffered The amount of the offer token being offered
     * @param _amountRequested The amount of the requested token being requested
     */
    function init(
        address _creator,
        IERC20 _offerToken,
        IERC20 _requestedToken,
        uint256 _amountOffered,
        uint256 _amountRequested
    ) external;

    /**
     * @param acceptor The address of the user accepting the swap
     * @notice Completes the swap by transferring the offered tokens to the acceptor and marking the vault/swap as completed
     */
    function completeSwapOffer(address acceptor) external;

    /// @notice Cancels the swap by returning the offered tokens to the creator and marking the vault/swap as cancelled
    function swapOfferCancelled() external;

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice This will revert if called before initialization
    function confirmOfferTokensAreLocked() external view returns (bool);
    /// @notice This will return Active before the contract is initialized
    function getSwapStatus() external view returns (SwapStatus);
    function getCreator() external view returns (address);
    function getOfferToken() external view returns (address);
    function getRequestedToken() external view returns (address);
    function getAmountOffered() external view returns (uint256);
    function getAmountRequested() external view returns (uint256);
}
