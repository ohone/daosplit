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
}
