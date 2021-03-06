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

    function test_SplitActive_ContributeTargetToken() public {
        address user = address(1);
        uint256 amount = 1337;

        vm.prank(owner);
        targetToken.mint(user, amount);

        vm.startPrank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        vm.stopPrank();

        // token ownership transferred to contract
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(targetToken.balanceOf(address(testContract)), amount);
        assertEq(testContract.contributedOf(user), amount);
    }

    function test_SplitActive_ContributeReward() public {
        vm.startPrank(owner);
        TestToken newToken = new TestToken();
        uint256 newTokenAmount = uint256(200);
        newToken.mint(owner, newTokenAmount);

        newToken.approve(address(testContract), newTokenAmount);
        testContract.addReward(owner, address(newToken), newTokenAmount);

        assertEq(newToken.balanceOf(address(testContract)), newTokenAmount);
    }

    function test_SplitActive_RefundReward_Reverts(bool contributed) public {
        vm.startPrank(owner);
        TestToken newToken = new TestToken();
        if (contributed) {
            uint256 newTokenAmount = uint256(200);
            newToken.mint(owner, newTokenAmount);
            newToken.approve(address(testContract), newTokenAmount);
            testContract.addReward(owner, address(newToken), newTokenAmount);
            vm.stopPrank();
            assertEq(newToken.balanceOf(address(testContract)), newTokenAmount);
        }

        vm.stopPrank();
        vm.expectRevert(bytes("no refunds"));

        testContract.refundReward(owner, address(newToken));
    }

    function test_SplitActive_ContributeNonTargetToken_reverts() public {
        address user = address(1);
        uint256 amount = 1337;

        vm.prank(owner);
        TestToken newToken = new TestToken();
        newToken.mint(user, amount);

        vm.startPrank(user);
        newToken.approve(address(testContract), amount);

        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        testContract.contribute(user, amount);
        vm.stopPrank();
    }

    function test_SplitExpired_RefundContribution() public {
        address user = address(1);
        uint256 amount = minContribution - 1;
        targetToken.mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // warp to completion
        vm.warp(expiry + 1);

        testContract.refundContribution(user);
        assertEq(targetToken.balanceOf(user), amount);
    }

    function test_SplitExpired_RefundRewards() public {
        address user = address(1);
        uint256 amount = uint256(1);

        targetToken.mint(user, amount);

        vm.prank(user);
        targetToken.approve(address(testContract), amount);

        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // populate rewards
        ContributedReward[] memory rewards = new ContributedReward[](5);
        populateRewardsRange(testContract, owner, rewards);

        // warp to completion
        vm.warp(expiry + 1);

        // assert each reward refunded
        for (uint256 index = 0; index < rewards.length; index++) {
            testContract.refundReward(owner, rewards[index].token);
            assertEq(
                TestToken(rewards[index].token).balanceOf(owner),
                rewards[index].amount
            );
        }
    }

    function test_SplitExpired_ClaimRewards_Reverts() public {
        address user = address(1);
        uint256 amount = 1;

        // give user some tokens, contribute
        targetToken.mint(user, amount);
        vm.prank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // populate rewards
        vm.startPrank(owner);
        address[] memory rewardsAddresses = new address[](5);
        for (uint256 index = 0; index < 5; index++) {
            TestToken token = new TestToken();
            token.mint(owner, index);
            token.approve(address(testContract), index);
            testContract.addReward(owner, address(token), index);
            rewardsAddresses[index] = address(token);
        }
        vm.stopPrank();

        // warp to completion
        vm.warp(expiry + 1);

        vm.startPrank(user);
        vm.expectRevert(bytes("not complete"));
        testContract.claimReward(user, rewardsAddresses);
        vm.stopPrank();
    }

    function test_SplitExpired_ContributeToken_Reverts() public {
        address user = address(1);
        uint256 amount = 1;

        // give user some tokens, contribute
        targetToken.mint(user, amount);
        vm.prank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // populate rewards
        populateRewardsRange(testContract, owner, new ContributedReward[](5));

        // warp to completion
        vm.warp(expiry + 1);

        vm.startPrank(user);
        vm.expectRevert(bytes("not active"));
        testContract.contribute(user, 1);
        vm.stopPrank();
    }

    function test_SplitComplete_RefundContribution_Reverts() public {
        address user = address(1337);
        uint256 amount = 100;

        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

        // transfer token allocation to user
        targetToken.mint(user, amount);
        vm.startPrank(user);

        // user contributes to daosplit
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // warp to complete split
        vm.warp(expiry + 1);

        // user attempts to get refund
        vm.expectRevert(bytes("no refunds"));
        testContract.refundContribution(user);

        vm.stopPrank();
    }

    function test_SplitComplete_RefundRewards_Reverts() public {
        // fuzz filter
        address user = address(1337);
        uint256 amount = 100;

        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

        // transfer token allocation to user
        targetToken.mint(user, amount);

        // user contributes to daosplit
        vm.startPrank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);
        vm.stopPrank();

        // populate rewards
        ContributedReward[] memory rewards = new ContributedReward[](5);
        populateRewardsRange(testContract, owner, rewards);

        // warp to complete split
        vm.warp(expiry + 1);

        // attempt to refund
        for (uint256 index = 0; index < rewards.length; index++) {
            vm.expectRevert(bytes("no refunds"));
            testContract.refundReward(owner, rewards[index].token);
        }
    }

    function test_SplitComplete_ClaimsRewards() public {
        address user = address(1);
        uint256 amount = 1337;

        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

        // mint tokens to user
        vm.prank(owner);
        targetToken.mint(user, amount);

        vm.startPrank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);
        vm.stopPrank();

        // populate rewards
        vm.startPrank(owner);
        uint8 rewardsCount = 5;
        address[] memory rewardsAddresses = new address[](rewardsCount);
        for (uint256 index = 0; index < rewardsCount; index++) {
            TestToken token = new TestToken();
            token.mint(owner, 1337);
            token.approve(address(testContract), 1337);
            testContract.addReward(owner, address(token), 1337);
            rewardsAddresses[index] = address(token);
        }
        vm.stopPrank();
        vm.warp(expiry + 1);

        // claim all rewards
        vm.prank(user);
        testContract.claimReward(user, rewardsAddresses);

        // assert rewards recieved
        for (uint256 index = 0; index < rewardsCount; index++) {
            assertTrue(TestToken(rewardsAddresses[index]).balanceOf(user) > 0);
        }
    }

    function testMinimumMet_multipleContributors_RewardProportionalToContribution()
        public
    {
        uint16 amount = 37;

        // contribute minimum to ensure completion
        uint256 totalContributed = contributeMinimum(
            owner,
            targetToken,
            testContract,
            minContribution
        );

        // populate user addresses
        address[] memory users = new address[](7);
        for (uint256 i = 0; i < users.length; i++) {
            users[i] = address(bytes20(uint160((i + 1) * amount)));
        }

        // populate rewards amounts
        uint256[] memory rewards = new uint256[](10);
        for (uint256 i = 0; i < rewards.length; i++) {
            rewards[i] = (i + 1) * amount;
        }

        // contribute per-user
        for (uint256 index = 0; index < users.length; index++) {
            uint256 fixedAmount;
            unchecked {
                fixedAmount = amount * (index + 1);
            }

            uint256 initialAmount = testContract.contributedOf(users[index]);

            // mint tokens to user
            vm.prank(owner);
            targetToken.mint(users[index], fixedAmount);
            // contribute tokens on behalf of user
            vm.startPrank(users[index]);
            targetToken.approve(address(testContract), fixedAmount);
            testContract.contribute(users[index], fixedAmount);
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
            token.mint(owner, rewards[index]);
            token.approve(address(testContract), rewards[index]);
            testContract.addReward(owner, address(token), rewards[index]);
        }
        vm.stopPrank();

        // fast forward to completion
        vm.warp(expiry + 1);
        require(testContract.isComplete());

        for (uint256 index = 0; index < users.length; index++) {
            uint256 contribution = testContract.contributedOf(users[index]);
            testContract.claimReward(users[index], rewardsAddresses);

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

    function test_SplitComplete_ClaimsNonExistingReward_Reverted() public {
        address user = address(1);
        uint256 amount = 1000;
        // populate minimum to ensure completion
        contributeMinimum(owner, targetToken, testContract, minContribution);

        vm.prank(owner);
        targetToken.mint(user, amount);

        vm.startPrank(user);
        targetToken.approve(address(testContract), amount);
        testContract.contribute(user, amount);
        vm.stopPrank();
        assertEq(targetToken.balanceOf(user), 0);
        assertEq(testContract.contributedOf(user), amount);

        // populate 5 different rewards
        vm.startPrank(owner);
        for (uint256 index = 0; index < 5; index++) {
            TestToken token = new TestToken();
            token.mint(owner, 200);
            token.approve(address(testContract), 200);
            testContract.addReward(owner, address(token), 200);
        }
        vm.stopPrank();

        vm.warp(expiry + 1);

        // claim non populated reward
        address[] memory rewardsAddresses = new address[](1);
        rewardsAddresses[0] = address(1337);
        vm.startPrank(user);
        vm.expectRevert(bytes("no rewards for token"));
        testContract.claimReward(user, rewardsAddresses);
        vm.stopPrank();
    }

    struct ContributedReward {
        address token;
        uint256 amount;
    }

    function populateRewardsRange(
        DaoSplit split,
        address user,
        ContributedReward[] memory rewards
    ) private {
        vm.startPrank(user);
        for (uint256 index = 0; index < rewards.length; index++) {
            TestToken token = new TestToken();
            token.mint(owner, 200);
            token.approve(address(testContract), 200);
            split.addReward(owner, address(token), 200);
            rewards[index] = (ContributedReward(address(token), 200));
        }
        vm.stopPrank();
    }

    function contributeMinimum(
        address tokenOwner,
        TestToken token,
        DaoSplit recipient,
        uint256 amount
    ) private returns (uint256) {
        vm.startPrank(tokenOwner);
        uint256 contributed = amount + 1;
        token.mint(tokenOwner, contributed);
        token.approve(address(recipient), contributed);
        recipient.contribute(tokenOwner, contributed);
        vm.stopPrank();
        return contributed;
    }
}
