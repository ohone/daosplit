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
    uint256 minContribution = 100;

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
        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);
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

    function testMinimumMet_ClaimsRewards(
        address user,
        uint256 amount,
        uint256[] calldata rewards
    ) public {
        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

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

    function testMinimumMet_multipleContributors_RewardProportionalToContribution(
        uint16 amount
    ) public {
        // populate user addresses
        address[] memory users = new address[](7);
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = address(bytes20(uint160((i + 1) * amount)));
        }

        // populate rewards amounts from
        uint256[] memory rewards = new uint256[](10);
        for (uint256 i = 0; i < rewards.length; i++) {
            rewards[i] = (i + 1) * amount;
        }

        // contribute minimum to ensure completion
        uint256 totalContributed = contributeMinimum(
            owner,
            targetToken,
            testContract,
            minContribution
        );

        // contribute per-user
        for (uint256 index = 0; index < users.length; index++) {
            uint256 fixedAmount;
            unchecked {
                fixedAmount = amount * (index + 1);
            }

            uint256 initialAmount = testContract.contributedOf(users[index]);

            // mint tokens to user
            vm.prank(owner);
            targetToken.Mint(users[index], fixedAmount);
            // contribute tokens on behalf of user
            vm.startPrank(users[index]);
            targetToken.approve(address(testContract), fixedAmount);
            testContract.Contribute(users[index], fixedAmount);
            vm.stopPrank();

            totalContributed += fixedAmount;
            assertEq(
                testContract.contributedOf(users[index]),
                fixedAmount + initialAmount
            );
        }

        // populate rewards
        vm.startPrank(owner);
        address[] memory rewardsAddresses = new address[](rewards.length);
        for (uint256 index = 0; index < rewards.length; index++) {
            TestToken token = new TestToken();
            rewardsAddresses[index] = address(token);
            token.Mint(owner, rewards[index]);
            token.approve(address(testContract), rewards[index]);
            testContract.AddReward(owner, address(token), rewards[index]);
        }
        vm.stopPrank();

        // fast forward to completion
        vm.warp(expiry + 1);
        require(testContract.isComplete());

        for (uint256 index = 0; index < users.length; index++) {
            uint256 contribution = testContract.contributedOf(users[index]);
            testContract.ClaimReward(users[index], rewardsAddresses);

            for (
                uint256 rewardIndex = 0;
                rewardIndex < rewards.length;
                rewardIndex++
            ) {
                assertEq(
                    TestToken(rewardsAddresses[rewardIndex]).balanceOf(
                        users[index]
                    ),
                    (rewards[rewardIndex] * contribution) / totalContributed
                );
            }
        }
    }

    function testMinimumMet_ClaimsNonExistingReward_Reverted(
        address user,
        uint256 amount,
        uint256[] calldata rewards
    ) public {
        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

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

    function contributeMinimum(
        address tokenOwner,
        TestToken token,
        DaoSplit recipient,
        uint256 amount
    ) private returns (uint256) {
        vm.startPrank(tokenOwner);
        uint256 contributed = amount + 1;
        token.Mint(tokenOwner, contributed);
        token.approve(address(recipient), contributed);
        recipient.Contribute(tokenOwner, contributed);
        vm.stopPrank();
        return contributed;
    }
}
