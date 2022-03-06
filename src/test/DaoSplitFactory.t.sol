// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.12;

import "ds-test/test.sol";
import "../DaoSplitFactory.sol";

contract DaoSplitFactoryTest is DSTest {
    DaoSplitFactory factory;

    function setUp() public {
        factory = new DaoSplitFactory();
    }

    function CreateSplit_ReturnsAddress() public {
        address splitAddress = factory.RegisterSplit(address(1), 100, 10);
        assertTrue(splitAddress != address(0));
    }
}
