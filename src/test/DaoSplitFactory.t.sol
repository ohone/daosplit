// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../DaoSplitFactory.sol";

contract DaoSplitFactoryTest is DSTest {
    DaoSplitFactory private factory;

    function setUp() public {
        factory = new DaoSplitFactory();
    }

    function test_createSplit_ReturnsAddress() public {
        address splitAddress = factory.registerSplit(address(1), 100, 10);
        assertTrue(splitAddress != address(0));
    }

    function test_createdSplit_WithSuppliedProperties() public {
        address targetToken = address(1);
        uint256 expiry = 100;
        uint256 minContribution = 10;
        address splitAddress = factory.registerSplit(
            targetToken,
            expiry,
            minContribution
        );
        DaoSplit createdSplit = DaoSplit(splitAddress);

        assertEq(uint256(expiry), createdSplit.expiry());
        assertEq(targetToken, createdSplit.targetToken());
        assertEq(minContribution, createdSplit.minContribution());
    }
}
