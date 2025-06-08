//SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

interface IReturnFunds {
    function returnMoney(address _beneficiary, uint256 _amount) external;
}
