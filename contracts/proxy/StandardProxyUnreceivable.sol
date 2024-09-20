// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract StandardProxyUnreceivable is TransparentUpgradeableProxy {
    constructor(address _logic, address initialOwner, bytes memory _data) payable
    TransparentUpgradeableProxy(_logic, initialOwner, _data) {}

    function getAdminAddress() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    function getImplementationAddress() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function proxyVersion() external pure returns (string memory) {
        return "StandardProxyUnreceivable240725";
    }

    receive() external payable { revert(); }
}
