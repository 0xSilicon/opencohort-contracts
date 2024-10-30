// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ICohortManager} from "../interface/ICohortManager.sol";
import {ICohort} from "../interface/ICohort.sol";
import {IOpenNameTag} from "../interface/IOpenNameTag.sol";

contract CohortManager is ICohortManager, Ownable, Initializable, UUPSUpgradeable {
    address private _cohort;
    address private _openNameTag;

    uint256 private _signerCount;
    mapping(address => bool) private _isValidSigner;

    uint256 private _cohortCount;
    mapping(uint256 => uint256) private _ownedCohorts;

    constructor() Ownable(address(0xdead)) {
        _disableInitializers();
    }

    function version() external pure returns (string memory) {
        return "CohortManager241024";
    }

    function initialize(address owner_, address cohort_, address openNameTag_) public initializer {
        _transferOwnership(owner_);

        _cohort = cohort_;
        _openNameTag = openNameTag_;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(hash);
        address signer = ECDSA.recover(signingHash, signature);
        if(isValidSigner(signer) || signer == owner()) return IERC1271.isValidSignature.selector;

        return 0xffffffff;
    }

    function cohort() public view returns (address) {
        return _cohort;
    }

    function openNameTag() public view returns (address) {
        return _openNameTag;
    }

    function signerCount() public view returns (uint256) {
        return _signerCount;
    }

    function isValidSigner(address signer) public view returns (bool) {
        return _isValidSigner[signer];
    }

    function cohortCount() public view returns (uint256) {
        return _cohortCount;
    }

    function ownedCohorts(uint256 index) public view returns (uint256) {
        return _ownedCohorts[index];
    }

    function mintNameTag(IOpenNameTag.NameTagMetadata calldata nameTagMetadata, string[] calldata keys, string[] calldata values) external onlyOwner {
        IOpenNameTag(openNameTag()).mint(nameTagMetadata, keys, values);
    }

    function addPropertyBatch(string[] calldata keys, string[] calldata values) external onlyOwner {
        IOpenNameTag(openNameTag()).addPropertyBatch(keys, values);
    }

    function removeProperty(string calldata key) external onlyOwner {
        IOpenNameTag(openNameTag()).removeProperty(key);
    }

    event SetSigner(address signer, bool valid);
    function setSigner(address signer, bool valid) external onlyOwner {
        require(signerCount() <= 10);
        require(signer != address(0));
        require(isValidSigner(signer) != valid);
        _isValidSigner[signer] = valid;

        if(valid) _signerCount += 1;
        else _signerCount -= 1;

        emit SetSigner(signer, valid);
    }

    event MintCohort(uint256 index, uint256 cohortId, CohortMetadata cohortMetadata);
    function mintCohort(CohortMetadata calldata cohortMetadata) external onlyOwner returns (uint256, uint256) {
        uint256 cohortId = ICohort(cohort()).mint(cohortMetadata);

        uint256 index = cohortCount();
        _ownedCohorts[index] = cohortId;
        _cohortCount = index + 1;

        emit MintCohort(index, cohortId, cohortMetadata);
        return (index, cohortId);
    }

    function setCohortGrant(uint256 tokenId, GrantConfig calldata cohortGrant) external onlyOwner {
        ICohort(cohort()).setCohortGrant(tokenId, cohortGrant);
    }

    function setTokenURI(uint256 tokenId, string calldata tokenURI) external onlyOwner {
        ICohort(cohort()).setTokenURI(tokenId, tokenURI);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
