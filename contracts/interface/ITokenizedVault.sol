// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITokenizedVault {
    function basedToken() external view returns (address);
    function spendableAdmin(address) external view returns (bool);
    function transferableAdmin(address) external view returns (bool);

    function setSpendableAdmin(address, bool) external;
    function setTransferableAdmin(address, bool) external;
    function setTransferableAdminBatch(address[] calldata, bool[] calldata) external;
}
