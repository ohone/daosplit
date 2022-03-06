// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../DaoSplit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Hevm.sol";
import "./TestToken.sol";

contract DaoSplitTest is DSTest {
    Hevm vm = Hevm(HEVM_ADDRESS);
    TestToken targetToken;
    TestToken[] rewardTokens;
    DaoSplit testContract;
    uint256 expiry = 100;
    uint256 minContribution = 10;

    function setUp() public {
        targetToken = new TestToken();
        rewardTokens = new TestToken[](5);
        rewardTokens[0] = new TestToken();
        rewardTokens[1] = new TestToken();
        rewardTokens[2] = new TestToken();
        rewardTokens[3] = new TestToken();
        rewardTokens[4] = new TestToken();

        testContract = new DaoSplit(
            address(targetToken),
            expiry,
            minContribution
        );

        for (uint256 index = 0; index < rewardTokens.length; index++) {
            rewardTokens[index].Mint(address(this), 10000);
        }
    }

    function testCanContributeTargetToken(address user, uint256 amount) public {
        targetToken.Mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.Contribute(user, amount);

        // token ownership transferred to contract
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(targetToken.balanceOf(address(testContract)), amount);
        assertEq(testContract.contributedOf(user), amount);
    }

    function testMinimumNotMet_CanRefundContribution(
        address user,
        uint256 amount
    ) public {
        // fuzz filter
        if (amount > minContribution) {
            return;
        }
        targetToken.Mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.Contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        vm.warp(expiry + 1);

        testContract.RefundContribution(user);
        assertEq(targetToken.balanceOf(user), amount);
    }

    function testMinimumNotMet_CanRefundRewards(address user, uint256 amount)
        public
    {
        // fuzz filter
        if (amount > minContribution) {
            return;
        }
        targetToken.Mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.Contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        vm.warp(expiry + 1);

        for (uint256 index = 0; index < rewardTokens.length; index++) {
            testContract.RefundReward(
                address(this),
                address(rewardTokens[index])
            );
            assertEq(rewardTokens[index].balanceOf(address(this)), 10000);
        }
    }

    function testMinimumMet_CanNotRefundContribution(
        address user,
        uint256 amount
    ) public {
        // fuzz filter
        if (amount > minContribution) {
            return;
        }
        targetToken.Mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.Contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        vm.warp(expiry + 1);

        vm.expectRevert(bytes(""));
        testContract.RefundContribution(user);
    }

    function testMinimumMet_CanClaimRewards(
        address user,
        address rewardSupplier,
        uint256 amount
    ) public {
        // fuzz filter
        if (amount > minContribution) {
            return;
        }
        targetToken.Mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.Contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        vm.startPrank(rewardSupplier);

        vm.warp(expiry + 1);

        address[] memory rewards = new address[](3);
        testContract.ClaimReward(user, rewards);

        for (uint256 index = 0; index < rewardTokens.length; index++) {
            assertEq(rewardTokens[index].balanceOf(user), 10000);
        }
    }
}
