// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HoldingVault is IHoldingVault {
    using SafeERC20 for IERC20;

    address private immutable i_factory;
    address private creator;
    IERC20 private offerToken;
    IERC20 private requestedToken;
    uint256 private amountOffered;
    uint256 private amountRequested;
    SwapStatus private swapStatus;

    modifier requireCallerIsFactory() {
        _requireCallerIsFactory();
        _;
    }

    /**
     * @dev Prevents the implementation contract from being initialized by an outsider
     */
    constructor(address _factory) {
        i_factory = _factory;
    }

    /*//////////////////////////////////////////////////////////////
       EXTERNAL FUNCTIONS - SHOULD ONLY BE CALLED BY THE FACTORY
    //////////////////////////////////////////////////////////////*/
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
    ) external requireCallerIsFactory {
        if (creator != address(0)) {
            revert HoldingVault__AlreadyInitialized();
        }
        creator = _creator;
        offerToken = _offerToken;
        requestedToken = _requestedToken;
        amountOffered = _amountOffered;
        amountRequested = _amountRequested;
    }

    /**
     * @param acceptor The address of the user accepting the swap
     * @notice Completes the swap by transferring the offered tokens to the acceptor and marking the vault/swap as completed
     */
    function completeSwapOffer(address acceptor) external requireCallerIsFactory {
        swapStatus = SwapStatus.Completed;
        offerToken.safeTransfer(acceptor, amountOffered);
    }

    /**
     * @notice Cancels the swap by returning the offered tokens to the creator and marking the vault/swap as cancelled
     */
    function swapOfferCancelled() external requireCallerIsFactory {
        swapStatus = SwapStatus.Cancelled;
        offerToken.safeTransfer(creator, amountOffered);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _requireCallerIsFactory() private view {
        if (msg.sender != i_factory) {
            revert HoldingVault__OnlyFactoryCanExecute();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function confirmOfferTokensAreLocked() external view returns (bool) {
        return offerToken.balanceOf(address(this)) >= amountOffered;
    }

    function getSwapStatus() external view returns (SwapStatus) {
        return swapStatus;
    }

    function getCreator() external view returns (address) {
        return creator;
    }

    function getOfferToken() external view returns (address) {
        return address(offerToken);
    }

    function getRequestedToken() external view returns (address) {
        return address(requestedToken);
    }

    function getAmountOffered() external view returns (uint256) {
        return amountOffered;
    }

    function getAmountRequested() external view returns (uint256) {
        return amountRequested;
    }
}
