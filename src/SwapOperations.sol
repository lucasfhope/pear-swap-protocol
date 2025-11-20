// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ISwapOperations, ISwapOperationsOwner} from "src/interfaces/ISwapOperations.sol";
import {HoldingVaultFactory} from "src/HoldingVaultFactory.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SwapOperations is ISwapOperations, ISwapOperationsOwner, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    HoldingVaultFactory private immutable i_holdingVaultFactory;
    mapping(address => bool) private s_allowedTokens;

    modifier isValidSwapOffer(SwapOffer memory swapOffer) {
        _isValidSwapOffer(swapOffer);
        _;
    }

    /**
     * @param _allowedTokens List of allowed token addresses for swapping
     * @notice This is assumed to be deployed with a list of known token addresses
     */
    constructor(address owner, address[] memory _allowedTokens) Ownable(owner) {
        for (uint256 i = 0; i < _allowedTokens.length;) {
            s_allowedTokens[_allowedTokens[i]] = true;
            emit AllowedTokenUpdated(_allowedTokens[i], true);
            unchecked {
                i++;
            }
        }
        i_holdingVaultFactory = new HoldingVaultFactory();
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Creates a new swap offer by deploying a holding vault and transferring offered tokens to it
     * @param swapOffer Swap offer details, including tokens and amounts
     * @notice Vaults/Swaps are created and tracked via the HoldingVaultFactory
     * @return Address of the holding vault created for the swap offer
     */
    function createSwapOffer(SwapOffer memory swapOffer)
        external
        isValidSwapOffer(swapOffer)
        nonReentrant
        returns (address)
    {
        IHoldingVault vault = IHoldingVault(
            i_holdingVaultFactory.createHoldingVaultForSwapOffer(
                msg.sender, swapOffer.offerToken, swapOffer.requestToken, swapOffer.offerAmount, swapOffer.requestAmount
            )
        );
        emit SwapOfferCreated(
            msg.sender,
            swapOffer.offerToken,
            swapOffer.requestToken,
            swapOffer.offerAmount,
            swapOffer.requestAmount,
            address(vault)
        );
        IERC20(swapOffer.offerToken).safeTransferFrom(msg.sender, address(vault), swapOffer.offerAmount);
        bool tokensAreLocked = vault.confirmOfferTokensAreLocked();
        if (!tokensAreLocked) {
            revert SwapOperations__VaultDidNotReceiveOfferTokens();
        }
        return address(vault);
    }

    /**
     * @notice Cancels an active swap offer, but only can be called by the offer creator while the offer is active
     * @param vaultAddress Address of the holding vault representing the swap offer
     * @notice Invokes the factory to return the offered tokens to the creator and mark the offer as cancelled
     */
    function cancelSwapOffer(address vaultAddress) external nonReentrant {
        address creatorOfSwapOffer = i_holdingVaultFactory.getCreatorOfVault(vaultAddress);
        if (creatorOfSwapOffer != msg.sender) {
            revert SwapOperations__NotCreatorOfSwapOffer();
        }
        if (IHoldingVault(vaultAddress).getSwapStatus() != IHoldingVault.SwapStatus.Active) {
            revert SwapOperations__SwapOfferNotActive();
        }
        emit SwapOfferCancelled(vaultAddress);
        i_holdingVaultFactory.setHoldingVaultAsCanceled(vaultAddress);
    }

    /**
     * @notice Accepts an active swap offer by transferring requested tokens to the offer creator and then sending the caller the locked tokens
     * @param vaultAddress Address of the holding vault representing the swap offer
     * @notice Completes the swap by invoking the factory to release the offered tokens to the acceptor
     */
    function acceptSwapOffer(address vaultAddress) external nonReentrant {
        address creatorOfSwapOffer = i_holdingVaultFactory.getCreatorOfVault(vaultAddress);
        if (creatorOfSwapOffer == address(0)) {
            revert SwapOperations__SwapOfferDoesntExist();
        }
        if (creatorOfSwapOffer == msg.sender) {
            revert SwapOperations__SwapOfferIsYourOwn();
        }
        if (IHoldingVault(vaultAddress).getSwapStatus() != IHoldingVault.SwapStatus.Active) {
            revert SwapOperations__SwapOfferNotActive();
        }
        emit SwapOfferCompleted(vaultAddress, msg.sender);
        IERC20(IHoldingVault(vaultAddress).getRequestedToken())
            .safeTransferFrom(msg.sender, creatorOfSwapOffer, IHoldingVault(vaultAddress).getAmountRequested());
        i_holdingVaultFactory.completeHoldingVaultSwap(vaultAddress, msg.sender);

        /// @dev no fee logic yet
    }

    /**
     * @notice Some centralization for allowing/disallowing tokens
     * @notice this assumes that the address is a known token address
     * @notice ownership could be transferred to a governance contract in the future
     * @dev should this check if it is IERC20 compatable?
     */
    function updateAllowedToken(address token, bool isAllowed) external onlyOwner {
        s_allowedTokens[token] = isAllowed;
        emit AllowedTokenUpdated(token, isAllowed);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @param swapOffer A SwapOffer with a offerToken, requestToken, offerTokenAmount, and requestTokenAmount
     * @notice Ensures both tokens are allowed, tokens in the swap are not the same, and offer/request amounts are greater than 0
     */
    function _isValidSwapOffer(SwapOffer memory swapOffer) private view {
        if (!s_allowedTokens[swapOffer.offerToken]) {
            revert SwapOperations__TokenNotAllowed(swapOffer.offerToken);
        }
        if (!s_allowedTokens[swapOffer.requestToken]) {
            revert SwapOperations__TokenNotAllowed(swapOffer.requestToken);
        }
        if (swapOffer.offerToken == swapOffer.requestToken) {
            revert SwapOperations__CantSwapSameToken();
        }
        if (swapOffer.offerAmount == 0 || swapOffer.requestAmount == 0) {
            revert SwapOperations__OfferAndRequestAmountsMustBeGreaterThanZero();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getHoldingVaultFactory() external view returns (address) {
        return address(i_holdingVaultFactory);
    }

    function isAllowedToken(address token) external view returns (bool) {
        return s_allowedTokens[token];
    }
}
