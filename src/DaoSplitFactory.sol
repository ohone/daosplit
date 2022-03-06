// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DaoSplit.sol";

contract DaoSplitFactory {
    struct Split {
        address targetToken;
        address recieveToken;
        uint256 amount;
        uint256 ratio;
        uint256 expires;
        bool withdrawable;
    }
    mapping(address => Split) ActiveSplits;
    mapping(address => uint256) Distributions;

    function RegisterSplit(
        address targetToken,
        uint256 expiry,
        uint256 minContribution
    ) external returns (address) {
        DaoSplit split = new DaoSplit(targetToken, expiry, minContribution);
        return address(split);
    }
}
