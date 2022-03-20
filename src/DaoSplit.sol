// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DaoSplit {
    uint256 public expiry;
    address public targetToken;
    mapping(address => uint256) public rewardsContributions;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public contributions;
    uint256 public contributed;
    uint256 public minContribution;

    constructor(
        address target,
        uint256 expiryBlock,
        uint256 minContrib
    ) {
        targetToken = target;
        expiry = expiryBlock;
        minContribution = minContrib;
    }

    function refundContribution(address recipient) public {
        require(isRefund(), "no refunds");
        IERC20(targetToken).transfer(recipient, contributions[recipient]);
    }

    function refundReward(address recipient, address reward) external {
        require(isRefund(), "no refunds");
        address id = address(
            bytes20(keccak256(abi.encodePacked(recipient, reward)))
        );
        uint256 contribution = rewardsContributions[id];
        rewardsContributions[id] = 0;
        IERC20(reward).transfer(recipient, contribution);
    }

    function claimReward(address recipient, address[] calldata requestedRewards)
        external
    {
        require(isComplete(), "isnt complete");
        uint256 contribution = contributions[recipient];
        require(contribution > 0, "no contributions to claim");
        contributions[recipient] = 0;

        for (uint256 index = 0; index < requestedRewards.length; index++) {
            require(
                rewards[requestedRewards[index]] != 0,
                "no rewards for token"
            );
            uint256 amount = rewardAmount(
                contribution,
                requestedRewards[index]
            );
            IERC20(requestedRewards[index]).transfer(recipient, amount);
        }
    }

    function contribute(address from, uint256 amount) external {
        require(isActive(), "isnt active");
        IERC20(targetToken).transferFrom(from, address(this), amount);
        contributions[from] += amount;
        contributed += amount;
    }

    function addReward(
        address from,
        address tokenAddress,
        uint256 amount
    ) external {
        require(isActive(), "isnt active");
        IERC20(tokenAddress).transferFrom(from, address(this), amount);
        rewards[tokenAddress] += amount;
    }

    function rewardAmount(uint256 contribution, address token)
        public
        view
        returns (uint256)
    {
        return (contribution * rewards[token]) / contributed;
    }

    function isComplete() public view returns (bool) {
        return block.timestamp > expiry && contributed >= minContribution;
    }

    function isActive() public view returns (bool) {
        return block.timestamp <= expiry;
    }

    function isRefund() public view returns (bool) {
        return block.timestamp > expiry && contributed < minContribution;
    }

    function contributedOf(address contributor)
        external
        view
        returns (uint256)
    {
        return contributions[contributor];
    }
}
