// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC1967Proxy, ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SimpleProxy is ERC1967Proxy {
    constructor(address implementation, bytes memory _data) payable ERC1967Proxy(implementation, _data) {}

    function getImplementationAddress() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function simpleProxyVersion() external pure returns (string memory) {
        return "SimpleProxy240603";
    }

    receive() external payable {}
}
