// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface INamedWallet {
    struct WalletInfo{
        string name;
        string image;
        string description;
        uint256 rate;
    }
    function changeInfo(string memory _name, string memory _image, string memory _description) external;
    function changeTaxRate(uint256 rate_) external;
    function addPropertyBatch(string[] calldata keys, string[] calldata values) external;
    function removeProperty(string calldata key) external;
    function upgradeImplementation(address newImplementation, bytes memory data, bytes calldata signature) external;
}
