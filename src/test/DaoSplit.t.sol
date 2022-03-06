// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../DaoSplit.sol";
import "./Hevm.sol";
import "./TestToken.sol";

contract DaoSplitTest is DSTest {
    address owner;
    Hevm vm = Hevm(HEVM_ADDRESS);
    TestToken targetToken;
    DaoSplit testContract;
    uint256 expiry = 100;
    uint256 minContribution = 10;

    function setUp() public {
        targetToken = new TestToken();
        testContract = new DaoSplit(
            address(targetToken),
            expiry,
            minContribution
        );
        owner = address(this);
    }

    function testCanContributeTargetToken(address user, uint256 amount) public {
        targetToken.Mint(user, amount);

        vm.startPrank(user);
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

    function testMinimumNotMet_CanRefundRewards(
        address user,
        uint256 amount,
        uint256[] calldata rewards
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

        // populate rewards
        vm.startPrank(owner);
        address[] memory rewardsAddresses = new address[](rewards.length);
        for (uint256 index = 0; index < rewards.length; index++) {
            TestToken token = new TestToken();
            token.Mint(owner, rewards[index]);
            token.approve(address(testContract), rewards[index]);
            testContract.AddReward(owner, address(token), rewards[index]);
            rewardsAddresses[index] = address(token);
        }

        vm.warp(expiry + 1);
        for (uint256 index = 0; index < rewards.length; index++) {
            testContract.RefundReward(owner, rewardsAddresses[index]);
            assertEq(
                TestToken(rewardsAddresses[index]).balanceOf(owner),
                rewards[index]
            );
        }
    }

    function testMinimumMet_RefundContribution_Reverts(
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

    function testMinimumMet_ClaimsAllRewards(
        address user,
        uint256 amount,
        uint256[] calldata rewards
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

        // populate rewards
        vm.startPrank(owner);
        address[] memory rewardsAddresses = new address[](rewards.length);
        for (uint256 index = 0; index < rewards.length; index++) {
            TestToken token = new TestToken();
            token.Mint(owner, rewards[index]);
            token.approve(address(testContract), rewards[index]);
            testContract.AddReward(owner, address(token), rewards[index]);
        }
        testContract.ClaimReward(user, rewardsAddresses);

        for (uint256 index = 0; index < rewards.length; index++) {
            assertEq(
                TestToken(rewardsAddresses[index]).balanceOf(user),
                rewards[index]
            );
        }
    }

    function testMinimumMet_ClaimsNonExistingReward_Reverted(
        address user,
        uint256 amount,
        uint256[] calldata rewards
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

        // populate rewards
        vm.startPrank(owner);
        for (uint256 index = 0; index < rewards.length; index++) {
            TestToken token = new TestToken();
            token.Mint(owner, rewards[index]);
            token.approve(address(testContract), rewards[index]);
            testContract.AddReward(owner, address(token), rewards[index]);
        }

        // claim non populated reward
        address[] memory rewardsAddresses = new address[](1);
        rewardsAddresses[0] = address(1);

        vm.expectRevert(bytes(""));
        testContract.ClaimReward(user, rewardsAddresses);
    }
}
