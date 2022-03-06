// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "./DaoSplit.sol";

contract DaoSplitFactory {
    function RegisterSplit(
        address targetToken,
        uint256 expiry,
        uint256 minContribution
    ) external returns (address) {
        DaoSplit split = new DaoSplit(targetToken, expiry, minContribution);
        return address(split);
    }
}
