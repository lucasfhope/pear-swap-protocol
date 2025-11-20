// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeploySwapOperations} from "script/DeploySwapOperations.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ISwapOperations, ISwapOperationsOwner} from "src/interfaces/ISwapOperations.sol";
import {IHoldingVaultFactory} from "src/interfaces/IHoldingVaultFactory.sol";
import {HoldingVault} from "src/HoldingVault.sol";
import {IHoldingVault} from "src/interfaces/IHoldingVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {ReentrantERC20} from "test/mocks/ReentrantERC20Mock.sol";
import {FeeOnTransferERC20Mock} from "test/mocks/FeeOnTransferERC20Mock.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SwapProtocolBaseTest is Test {
    ISwapOperations swapOperations;
    ISwapOperationsOwner swapOperationsOwner;
    IHoldingVaultFactory holdingVaultFactory;
    IHoldingVault holdingVaultImplementation;

    address owner = makeAddr("owner");
    address steven = makeAddr("steven");
    address michael = makeAddr("michael");
    address nick = makeAddr("nick");
    address scott = makeAddr("scott");

    IERC20 weth;
    IERC20 usdc;
    IERC20 link;
    IERC20 dai;

    uint256 wethMintAmount = 100e18;
    uint256 usdcMintAmount = 100000e6;
    uint256 linkMintAmount = 10000e18;
    uint256 daiMintAmount = 100000e18;

    uint256 wethOfferAmount = 10e18;
    uint256 wethRequestAmount = 3e18;
    uint256 usdcOfferAmount = 1535e6;
    uint256 usdcRequestAmount = 35000e6;
    uint256 linkOfferAmount = 200e18;
    uint256 linkRequestAmount = 100e18;
    uint256 daiOfferAmount = 10000e18;
    uint256 daiRequestAmount = 3100e18;

    function setUp() public virtual {
        DeploySwapOperations deployer = new DeploySwapOperations();
        (address _swapOperations, address _helperConfig) = deployer.deploySwapOperations(owner);
        swapOperations = ISwapOperations(_swapOperations);
        swapOperationsOwner = ISwapOperationsOwner(_swapOperations);
        HelperConfig.NetworkConfig memory networkConfig = HelperConfig(_helperConfig).getConfig();
        holdingVaultFactory = IHoldingVaultFactory(swapOperations.getHoldingVaultFactory());
        holdingVaultImplementation = IHoldingVault(holdingVaultFactory.getImplementation());

        weth = IERC20(networkConfig.weth);
        usdc = IERC20(networkConfig.usdc);
        link = IERC20(networkConfig.link);
        dai = IERC20(networkConfig.dai);

        deal(address(weth), steven, wethMintAmount);
        deal(address(usdc), michael, usdcMintAmount);
        deal(address(link), nick, linkMintAmount);
        deal(address(dai), scott, daiMintAmount);
    }

    function testAllowedTokens() external view {
        assert(swapOperations.isAllowedToken(address(weth)));
        assert(swapOperations.isAllowedToken(address(usdc)));
        assert(swapOperations.isAllowedToken(address(link)));
        assert(swapOperations.isAllowedToken(address(dai)));
        assert(!swapOperations.isAllowedToken(0x7169D38820dfd117C3FA1f22a697dBA58d90BA06));
    }

    function testCanCreateSwapOffert() external {
        vm.startPrank(steven);
        weth.approve(address(swapOperations), wethOfferAmount);
        vm.expectEmit(true, true, true, false);
        emit ISwapOperations.SwapOfferCreated(
            steven, address(weth), address(usdc), wethOfferAmount, usdcRequestAmount, address(0)
        );
        IHoldingVault vault = IHoldingVault(
            swapOperations.createSwapOffer(
                ISwapOperations.SwapOffer({
                    offerToken: address(weth),
                    requestToken: address(usdc),
                    offerAmount: wethOfferAmount,
                    requestAmount: usdcRequestAmount
                })
            )
        );
        vm.stopPrank();
        assert(weth.balanceOf(address(vault)) == wethOfferAmount);
        assert(weth.balanceOf(steven) == wethMintAmount - wethOfferAmount);
    }

    function testRevertsWhenCreatingSwapOfferWithInvalidToken() external {
        uint256 amount = 1000e18;
        ERC20Mock fakeToken = new ERC20Mock("Fake Token", "FAKE");
        fakeToken.mint(steven, amount);
        vm.startPrank(steven);
        fakeToken.approve(address(swapOperations), amount);
        vm.expectRevert(
            abi.encodeWithSelector(ISwapOperations.SwapOperations__TokenNotAllowed.selector, address(fakeToken))
        );
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(fakeToken), requestToken: address(usdc), offerAmount: amount, requestAmount: amount
            })
        );
        weth.approve(address(swapOperations), amount);
        vm.expectRevert(
            abi.encodeWithSelector(ISwapOperations.SwapOperations__TokenNotAllowed.selector, address(fakeToken))
        );
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(weth), requestToken: address(fakeToken), offerAmount: amount, requestAmount: amount
            })
        );
        vm.stopPrank();
    }

    function testRevertsWhenCreatingSwapOfferWithZeroAmount() external {
        vm.startPrank(steven);
        weth.approve(address(swapOperations), wethOfferAmount);
        vm.expectRevert(ISwapOperations.SwapOperations__OfferAndRequestAmountsMustBeGreaterThanZero.selector);
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(weth), requestToken: address(usdc), offerAmount: 0, requestAmount: usdcRequestAmount
            })
        );
        vm.expectRevert(ISwapOperations.SwapOperations__OfferAndRequestAmountsMustBeGreaterThanZero.selector);
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(weth), requestToken: address(usdc), offerAmount: wethOfferAmount, requestAmount: 0
            })
        );
        vm.stopPrank();
    }

    function testRevertsWhenCreatingSwapOfferWithSameToken() external {
        vm.startPrank(steven);
        weth.approve(address(swapOperations), wethOfferAmount);
        vm.expectRevert(ISwapOperations.SwapOperations__CantSwapSameToken.selector);
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(weth),
                requestToken: address(weth),
                offerAmount: wethOfferAmount,
                requestAmount: wethOfferAmount
            })
        );
        vm.stopPrank();
    }

    function testCanCancelSwapOffer() external {
        uint256 usdcBalanceBeforeSwapOffer = usdc.balanceOf(michael);
        IHoldingVault vault = _makeSwapOffer(michael, address(usdc), address(link), usdcOfferAmount, linkRequestAmount);
        uint256 usdcBalanceAfterSwapOffer = usdc.balanceOf(michael);
        assert(usdcBalanceAfterSwapOffer + usdcOfferAmount == usdcBalanceBeforeSwapOffer);

        vm.startPrank(michael);
        vm.expectEmit(true, false, false, false);
        emit ISwapOperations.SwapOfferCancelled(address(vault));
        swapOperations.cancelSwapOffer(address(vault));
        vm.stopPrank();

        uint256 usdcBalanceAfterCancel = usdc.balanceOf(michael);
        assert(usdcBalanceAfterCancel == usdcBalanceBeforeSwapOffer);
        assert(weth.balanceOf(address(vault)) == 0);
    }

    function testRevertsWhenNonCreatorTriesToCancelSwapOffer() external {
        IHoldingVault vault = _makeSwapOffer(nick, address(link), address(dai), linkOfferAmount, daiRequestAmount);
        vm.startPrank(scott);
        vm.expectRevert(ISwapOperations.SwapOperations__NotCreatorOfSwapOffer.selector);
        swapOperations.cancelSwapOffer(address(vault));
        vm.stopPrank();
    }

    function testCompleteSwapOffer() external {
        uint256 scottUsdcBalanceBeforeSwapOffer = usdc.balanceOf(scott);
        uint256 scottDaiBalanceBeforeSwapOffer = dai.balanceOf(scott);
        uint256 michaelUsdcBalanceBeforeSwapOffer = usdc.balanceOf(michael);
        uint256 michaelDaiBalanceBeforeSwapOffer = dai.balanceOf(michael);

        IHoldingVault vault = _makeSwapOffer(scott, address(dai), address(usdc), daiOfferAmount, usdcRequestAmount);

        vm.startPrank(michael);
        usdc.approve(address(swapOperations), wethRequestAmount);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();

        uint256 scottUsdcBalanceAfterSwapCompletion = usdc.balanceOf(scott);
        uint256 scottDaiBalanceAfterSwapCompletion = dai.balanceOf(scott);
        uint256 michaelUsdcBalanceAfterSwapCompletion = usdc.balanceOf(michael);
        uint256 michaelDaiBalanceAfterSwapCompletion = dai.balanceOf(michael);

        assert(scottUsdcBalanceAfterSwapCompletion == scottUsdcBalanceBeforeSwapOffer + usdcRequestAmount);
        assert(scottDaiBalanceAfterSwapCompletion == scottDaiBalanceBeforeSwapOffer - daiOfferAmount);
        assert(michaelUsdcBalanceAfterSwapCompletion == michaelUsdcBalanceBeforeSwapOffer - usdcRequestAmount);
        assert(michaelDaiBalanceAfterSwapCompletion == michaelDaiBalanceBeforeSwapOffer + daiOfferAmount);
    }

    function testOwnerCanAllowAndDisallowTokens() external {
        ERC20Mock memeCoin = new ERC20Mock("Meme Token", "MEME");
        vm.prank(owner);
        swapOperationsOwner.updateAllowedToken(address(memeCoin), true);
        assert(swapOperations.isAllowedToken(address(memeCoin)));
        vm.prank(owner);
        swapOperationsOwner.updateAllowedToken(address(memeCoin), false);
        assert(!swapOperations.isAllowedToken(address(memeCoin)));
    }

    function testRevertsWhenNonOwnerTriesToUpdateAllowedTokens() external {
        vm.prank(nick);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nick));
        swapOperationsOwner.updateAllowedToken(address(link), false);
    }

    function testDisallowingTokensDoesNotEffectExistingSwapOffers() external {
        IHoldingVault vault = _makeSwapOffer(steven, address(weth), address(usdc), wethOfferAmount, usdcRequestAmount);

        vm.startPrank(owner);
        swapOperationsOwner.updateAllowedToken(address(weth), false);
        swapOperationsOwner.updateAllowedToken(address(usdc), false);
        vm.stopPrank();

        vm.startPrank(michael);
        usdc.approve(address(swapOperations), usdcOfferAmount);
        vm.expectRevert(abi.encodeWithSelector(ISwapOperations.SwapOperations__TokenNotAllowed.selector, address(usdc)));
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(usdc),
                requestToken: address(link),
                offerAmount: usdcOfferAmount,
                requestAmount: linkRequestAmount
            })
        );
        vm.stopPrank();

        vm.startPrank(michael);
        usdc.approve(address(swapOperations), daiRequestAmount);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();
    }

    function testRevertsOnTokenReentrancy() external {
        ReentrantERC20 reentrantToken = new ReentrantERC20();
        uint256 mintAmount = 1e18;
        reentrantToken.mint(steven, mintAmount);
        reentrantToken.configureReentry(address(swapOperations), ISwapOperations.cancelSwapOffer.selector, true);

        vm.prank(owner);
        swapOperationsOwner.updateAllowedToken(address(reentrantToken), true);

        vm.startPrank(steven);
        reentrantToken.approve(address(swapOperations), wethOfferAmount);
        vm.expectEmit(false, false, false, true, address(reentrantToken));
        emit ReentrantERC20.ReentrancyAttempt(
            false, abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        IHoldingVault(
            swapOperations.createSwapOffer(
                ISwapOperations.SwapOffer({
                    offerToken: address(reentrantToken),
                    requestToken: address(usdc),
                    offerAmount: mintAmount,
                    requestAmount: usdcRequestAmount
                })
            )
        );
        vm.stopPrank();
    }

    function testRevertsWhenAttemptingToReinitializeHoldingVault() external {
        IHoldingVault vault = _makeSwapOffer(steven, address(weth), address(usdc), wethOfferAmount, usdcRequestAmount);

        vm.startPrank(address(holdingVaultFactory));
        vm.expectRevert(abi.encodeWithSelector(IHoldingVault.HoldingVault__AlreadyInitialized.selector));
        vault.init(steven, IERC20(address(weth)), IERC20(address(usdc)), wethOfferAmount, usdcRequestAmount);
        vm.stopPrank();
    }

    function testRevertsWhenVaultDoesNotReceiveTheFullAmountOffered() external {
        FeeOnTransferERC20Mock feeOnTransferToken = new FeeOnTransferERC20Mock();
        uint256 mintAmount = 1000e18;
        feeOnTransferToken.mint(steven, mintAmount);

        vm.prank(owner);
        swapOperationsOwner.updateAllowedToken(address(feeOnTransferToken), true);

        vm.startPrank(steven);
        feeOnTransferToken.approve(address(swapOperations), mintAmount);
        vm.expectRevert(ISwapOperations.SwapOperations__VaultDidNotReceiveOfferTokens.selector);
        swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: address(feeOnTransferToken),
                requestToken: address(usdc),
                offerAmount: mintAmount,
                requestAmount: usdcRequestAmount
            })
        );
        vm.stopPrank();
    }

    function testRevertsWhenAcceptSwapOfferIsCalledOnNonVaultAddress() external {
        vm.startPrank(michael);
        address fakeVault = address(new HoldingVault(address(holdingVaultFactory)));
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferDoesntExist.selector);
        swapOperations.acceptSwapOffer(fakeVault);
        vm.stopPrank();
    }

    function testRevertsWhenCreatorOfSwapOfferTriesToAcceptTheirOffer() external {
        IHoldingVault vault = _makeSwapOffer(nick, address(link), address(dai), linkOfferAmount, daiRequestAmount);
        vm.startPrank(nick);
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferIsYourOwn.selector);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();
    }

    function testRevertsWhenAcceptSwapOfferIsCalledWhenTheVaultIsNotActive() external {
        IHoldingVault vault = _makeSwapOffer(nick, address(link), address(dai), linkOfferAmount, daiRequestAmount);
        vm.prank(nick);
        swapOperations.cancelSwapOffer(address(vault));
        vm.startPrank(scott);
        dai.approve(address(swapOperations), daiRequestAmount);
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferNotActive.selector);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();

        vault = _makeSwapOffer(steven, address(weth), address(dai), wethOfferAmount, daiRequestAmount);
        vm.startPrank(scott);
        dai.approve(address(swapOperations), daiRequestAmount);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();
        deal(address(dai), michael, daiRequestAmount);
        vm.startPrank(michael);
        dai.approve(address(swapOperations), daiRequestAmount);
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferNotActive.selector);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();
    }

    function testRevertsWhenCancelSwapOfferIsCalledWhenTheVaultIsNotActive() external {
        IHoldingVault vault = _makeSwapOffer(nick, address(link), address(dai), linkOfferAmount, daiRequestAmount);
        vm.startPrank(nick);
        swapOperations.cancelSwapOffer(address(vault));
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferNotActive.selector);
        swapOperations.cancelSwapOffer(address(vault));
        vm.stopPrank();

        vault = _makeSwapOffer(steven, address(weth), address(dai), wethOfferAmount, daiRequestAmount);
        vm.startPrank(scott);
        dai.approve(address(swapOperations), daiRequestAmount);
        swapOperations.acceptSwapOffer(address(vault));
        vm.stopPrank();
        vm.startPrank(steven);
        vm.expectRevert(ISwapOperations.SwapOperations__SwapOfferNotActive.selector);
        swapOperations.cancelSwapOffer(address(vault));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          HOLDING_VAULT_FACTORY
    //////////////////////////////////////////////////////////////*/
    function testRevertsWhenCreatingSwapThroughFactoryDirectly() external {
        vm.startPrank(scott);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, scott));
        holdingVaultFactory.createHoldingVaultForSwapOffer(
            steven, address(weth), address(usdc), wethOfferAmount, usdcRequestAmount
        );
        vm.stopPrank();
    }

    function testRevertsWhenCancelingSwapThroughFactoryDirectly() external {
        IHoldingVault vault = _makeSwapOffer(scott, address(dai), address(weth), daiOfferAmount, wethRequestAmount);
        vm.startPrank(scott);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, scott));
        holdingVaultFactory.setHoldingVaultAsCanceled(address(vault));
        vm.stopPrank();
    }

    function testRevertsWhenCompletingSwapThroughFactoryDirectly() external {
        IHoldingVault vault = _makeSwapOffer(steven, address(weth), address(dai), wethOfferAmount, daiRequestAmount);
        vm.startPrank(michael);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, michael));
        holdingVaultFactory.completeHoldingVaultSwap(address(vault), michael);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                       HOLDING_VAULT_IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    function testImplementationCannotBeInitializedByNonFactory() external {
        vm.startPrank(steven);
        vm.expectRevert(abi.encodeWithSelector(IHoldingVault.HoldingVault__OnlyFactoryCanExecute.selector, steven));
        holdingVaultImplementation.init(
            steven, IERC20(address(weth)), IERC20(address(usdc)), wethOfferAmount, usdcRequestAmount
        );
        vm.stopPrank();
    }

    function testImplementationCannotCompleteSwapByNonFactory() external {
        vm.startPrank(steven);
        vm.expectRevert(abi.encodeWithSelector(IHoldingVault.HoldingVault__OnlyFactoryCanExecute.selector, steven));
        holdingVaultImplementation.completeSwapOffer(steven);
        vm.stopPrank();
    }

    function testImplementationCannotCancelSwapByNonFactory() external {
        vm.startPrank(steven);
        vm.expectRevert(abi.encodeWithSelector(IHoldingVault.HoldingVault__OnlyFactoryCanExecute.selector, steven));
        holdingVaultImplementation.swapOfferCancelled();
        vm.stopPrank();
    }

    function testImplementationGetters() external {
        assert(holdingVaultImplementation.getSwapStatus() == IHoldingVault.SwapStatus.Active);
        assert(holdingVaultImplementation.getCreator() == address(0));
        assert(holdingVaultImplementation.getAmountOffered() == 0);
        assert(holdingVaultImplementation.getAmountRequested() == 0);
        assert(holdingVaultImplementation.getOfferToken() == address(0));
        assert(holdingVaultImplementation.getRequestedToken() == address(0));
        vm.expectRevert();
        holdingVaultImplementation.confirmOfferTokensAreLocked();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _makeSwapOffer(
        address creator,
        address offerToken,
        address requestToken,
        uint256 offerAmount,
        uint256 requestAmount
    ) private returns (IHoldingVault) {
        vm.startPrank(creator);
        IERC20(offerToken).approve(address(swapOperations), offerAmount);
        address vault = swapOperations.createSwapOffer(
            ISwapOperations.SwapOffer({
                offerToken: offerToken,
                requestToken: requestToken,
                offerAmount: offerAmount,
                requestAmount: requestAmount
            })
        );
        vm.stopPrank();
        return IHoldingVault(vault);
    }
}
