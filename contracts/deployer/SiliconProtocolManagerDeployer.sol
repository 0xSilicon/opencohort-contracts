// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SiliconProtocolManager} from "../utils/SiliconProtocolManager.sol";

contract SiliconProtocolManagerDeployer is Ownable, UUPSUpgradeable, Initializable {
    address private _cohort;
    address private _openNameTag;
    address private _siliconProtocolManagerImplementation;

    mapping(address => address) private _siliconProtocolManager;

    address private _walletFactory;

    constructor() Ownable(address(0xdead)) {
        _disableInitializers();
    }

    function version() external pure returns (string memory) {
        return "SiliconProtocolManagerDeployer250109";
    }

    function initialize(address owner_, address cohort_, address openNameTag_, address walletFactory_) public reinitializer(2) {
        _transferOwnership(owner_);

        _cohort = cohort_;
        _openNameTag = openNameTag_;

        _siliconProtocolManagerImplementation = address(new SiliconProtocolManager());
        _walletFactory = walletFactory_;
    }

    function cohort() public view returns (address) {
        return _cohort;
    }

    function openNameTag() public view returns (address) {
        return _openNameTag;
    }

    function siliconProtocolManagerImplementation() public view returns (address) {
        return _siliconProtocolManagerImplementation;
    }

    function walletFactory() public view returns (address) {
        return _walletFactory;
    }

    function siliconProtocolManager(address ownerOfManager) public view returns (address) {
        return _siliconProtocolManager[ownerOfManager];
    }

    event SetSiliconProtocolManagerImplementation(address siliconProtocolManagerImplementation);
    function setSiliconProtocolManagerImplementation() external onlyOwner {
        _siliconProtocolManagerImplementation = address(new SiliconProtocolManager());
        emit SetSiliconProtocolManagerImplementation(_siliconProtocolManagerImplementation);
    }

    event DeploySiliconProtocolManager(address ownerOfManager, address siliconProtocolManager);
    function deploySiliconProtocolManager() external {
        address ownerOfManager = msg.sender;
        require(siliconProtocolManager(ownerOfManager) == address(0));

        address siliconProtocolManager_ = address(new ERC1967Proxy(
            siliconProtocolManagerImplementation(),
            abi.encodeCall(SiliconProtocolManager.initialize, (ownerOfManager, cohort(), openNameTag(), walletFactory()))
        ));
        _siliconProtocolManager[ownerOfManager] = siliconProtocolManager_;

        emit DeploySiliconProtocolManager(ownerOfManager, siliconProtocolManager_);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
