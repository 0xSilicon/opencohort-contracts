// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IProxy {
    function getAdminAddress() external view returns (address);
    function owner() external view returns (address);
    function owner_() external view returns (address);
}
