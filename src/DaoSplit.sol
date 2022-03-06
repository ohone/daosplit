// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DaoSplit {
    uint256 Expiry;
    address TargetToken;
    mapping(address => uint256) RewardsContributions;
    mapping(address => uint256) Rewards;
    mapping(address => uint256) Contributions;
    uint256 contributed;
    uint256 MinContribution;

    constructor(
        address targetToken,
        uint256 expiry,
        uint256 minContribution
    ) {
        TargetToken = targetToken;
        Expiry = expiry;
        MinContribution = minContribution;
    }

    function RefundContribution(address recipient) public {
        require(isRefund(), "no refunds yet");
        IERC20(TargetToken).transfer(recipient, Contributions[recipient]);
    }

    function RefundReward(address recipient, address reward) external {
        require(isRefund(), "no refunds");
        address id = address(
            bytes20(keccak256(abi.encodePacked(recipient, reward)))
        );
        uint256 contribution = RewardsContributions[id];
        RewardsContributions[id] = 0;
        IERC20(reward).transfer(recipient, contribution);
    }

    function ClaimReward(address recipient, address[] calldata rewards)
        external
    {
        require(isComplete(), "isnt complete");
        uint256 contribution = Contributions[recipient];

        // guard against reentry
        require(contribution > 0);
        Contributions[recipient] = 0;

        for (uint256 index = 0; index < rewards.length; index++) {
            uint256 amount = rewardAmount(contribution, rewards[index]);
            IERC20(rewards[index]).transfer(recipient, amount);
        }
    }

    function Contribute(address from, uint256 amount) external {
        require(isActive(), "isnt active");
        IERC20(TargetToken).transferFrom(from, address(this), amount);
        Contributions[from] += amount;
        contributed += amount;
    }

    function AddReward(
        address from,
        address tokenAddress,
        uint256 amount
    ) external {
        require(isActive(), "isnt active");
        IERC20(tokenAddress).transferFrom(from, address(this), amount);
        Rewards[tokenAddress] += amount;
    }

    function rewardAmount(uint256 contribution, address token)
        public
        view
        returns (uint256)
    {
        return (contribution * Rewards[token]) / contributed;
    }

    function isComplete() public view returns (bool) {
        return block.number > Expiry && contributed >= MinContribution;
    }

    function isActive() public view returns (bool) {
        return block.number < Expiry;
    }

    function isRefund() public view returns (bool) {
        return block.number > Expiry && contributed < MinContribution;
    }

    function contributedOf(address contributor)
        external
        view
        returns (uint256)
    {
        return Contributions[contributor];
    }
}
