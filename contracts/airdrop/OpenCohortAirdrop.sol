// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IOpenCohortAirdrop} from "../interface/IOpenCohortAirdrop.sol";
import {ICohort} from "../interface/ICohort.sol";
import {IERC5192} from "../interface/IERC5192.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

error AlreadyClaimed();
error InvalidProof();

contract OpenCohortAirdrop is IOpenCohortAirdrop, Ownable, Initializable, ERC165, IERC5192, IERC721Errors {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    uint256 private _totalSupply;

    address[] private _ownerList;
    mapping(address => uint256[]) private _tokenIdList;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    address private _cohort;
    CohortMetadata private _cohortMetadata;
    CohortGrant private _cohortGrant;
    uint256 private _cohortGrantRateDenominator;

    OpenCohortAirdropConfig private _openCohortAirdropConfig;
    uint256 private _cohortId;
    uint256 private _cohortTime;

    mapping(address => uint256) private _claimedAmount;
    mapping(uint256 => uint256) private _claimedBitMap;

    constructor() Ownable(address(0xdead)) {
        _disableInitializers();
    }

    function initialize(address owner_, address cohort_, OpenCohortAirdropConfig memory openCohortAirdropConfig_, uint256 cohortId_, uint256 cohortTime_) public initializer {
        _transferOwnership(owner_);

        _cohort = cohort_;
        _openCohortAirdropConfig = openCohortAirdropConfig_;

        if(cohortId_ != 0) _setCohortId(cohortId_);
        if(cohortTime_ != 0) _setCohortTime(cohortTime_);
    }

    receive() external payable { revert(); }

    function version() external pure returns (string memory) {
        return "OpenCohortAirdrop240819A";
    }

    //////////////////////////////////////////////////////////////////
    // ERC5192 Interface
    function locked(uint256) external pure returns (bool) { return true; }
    //////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////
    // ERC721 Interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    function getOwnerListLength() public view returns (uint256) {
        return _ownerList.length;
    }

    function getOwnerByIndex(uint256 idx) public view returns (address) {
        return _ownerList[idx];
    }

    function getTokenIdByIndex(address owner, uint256 idx) public view returns (uint256) {
        return _tokenIdList[owner][idx];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function name() public view virtual returns (string memory) {
        if(bytes(openCohortAirdropConfig().name).length == 0)
            return string(abi.encodePacked("OpenCohort: ", IERC20Metadata(openCohortAirdropConfig().token).name()));
        return string(abi.encodePacked("OpenCohort: ", openCohortAirdropConfig().name));
    }

    function symbol() public view virtual returns (string memory) {
        return "OCA";
    }

    function baseURI() public view virtual returns (string memory) {
        return _openCohortAirdropConfig.baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI_ = baseURI();
        return bytes(baseURI_).length > 0 ? string.concat(baseURI_, tokenId.toString()) : "";
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        _totalSupply += 1;
        if(balanceOf(to) == 0) _ownerList.push(to);
        _tokenIdList[to].push(tokenId);
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Locked(tokenId);
        emit Transfer(address(0), to, tokenId);
    }

    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    event SetBaseURI(string baseURI);
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _openCohortAirdropConfig.baseURI = baseURI_;
        emit SetBaseURI(baseURI_);
    }


    event SetName(string name);
    function setName(string calldata name_) external onlyOwner {
        _openCohortAirdropConfig.name = name_;
        emit SetName(name_);
    }

    event SetDescription(string description);
    function setDescription(string calldata description_) external onlyOwner {
        _openCohortAirdropConfig.description = description_;
        emit SetDescription(description_);
    }

    event SetImage(string image);
    function setImage(string calldata image_) external onlyOwner {
        _openCohortAirdropConfig.image = image_;
        emit SetImage(image_);
    }

    ///////////////////////////////////////////////////////////////////

    function cohort() public view returns (address) {
        return _cohort;
    }

    function cohortMetadata() public view returns (CohortMetadata memory) {
        return _cohortMetadata;
    }

    function cohortGrant() public view returns (CohortGrant memory) {
        return _cohortGrant;
    }

    function cohortGrantRateDenominator() public view returns (uint256) {
        return _cohortGrantRateDenominator;
    }

    function openCohortAirdropConfig() public view returns (OpenCohortAirdropConfig memory) {
        return _openCohortAirdropConfig;
    }

    function claimableTime() public view returns (uint256) {
        return _openCohortAirdropConfig.claimableTime;
    }

    function signer() public view returns (address) {
        return _openCohortAirdropConfig.signer;
    }

    function image() public view returns (string memory) {
        return _openCohortAirdropConfig.image;
    }

    function cohortId() public view returns (uint256) {
        return _cohortId;
    }

    function cohortTime() public view returns (uint256) {
        return _cohortTime;
    }

    event SetCohortId(uint256 cohortId, CohortGrant cohortGrant, uint256 cohortGrantRateDenominator);
    function setCohortId(uint256 cohortId_) external onlyOwner {
        _setCohortId(cohortId_);
    }

    function _setCohortId(uint256 cohortId_) internal {
        require(cohortId() == 0);

        ICohort Cohort = ICohort(cohort());
        require(Cohort.ownerOf(cohortId_) != address(0));
        if(Cohort.cohortType(cohortId_) == CohortType.Address) require(signer() == address(0));
        else require(signer() != address(0));

        _cohortId = cohortId_;
        _cohortGrant = Cohort.grant(cohortId_);
        _cohortGrantRateDenominator = Cohort.GRANT_RATE_DENOMINATOR();
        emit SetCohortId(cohortId_, _cohortGrant, _cohortGrantRateDenominator);
    }

    event SetCohortTime(uint256 cohortTime, CohortMetadata cohortMetadata);
    function setCohortTime(uint256 cohortTime_) external onlyOwner {
        _setCohortTime(cohortTime_);
    }

    function _setCohortTime(uint256 cohortTime_) internal {
        require(cohortTime() == 0);
        require(cohortId() != 0);
        require(openCohortAirdropConfig().rewardType != RewardType.Unit);

        CohortMetadata memory cohortMetadata_ = ICohort(cohort()).getExactTimeSnapShot(cohortId(), cohortTime_);
        require(cohortMetadata_.merkleRoot != 0);

        _cohortTime = cohortTime_;
        _cohortMetadata = cohortMetadata_;
        emit SetCohortTime(cohortTime_, cohortMetadata_);
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = _claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        _claimedBitMap[claimedWordIndex] = _claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    event Claimed(uint256 index, address uniqueKey, uint256 weight, uint256 amount, address beneficiary);
    function claim(uint256 index, address uniqueKey, uint256 weight, bytes32[] calldata proof) external {
        OpenCohortAirdropConfig memory config = openCohortAirdropConfig();
        require(config.signer == address(0));
        _claim(config, index, uniqueKey, weight, proof, uniqueKey);
    }

    function claimBySignature(uint256 index, address uniqueKey, uint256 weight, bytes32[] calldata proof, address beneficiary, bytes memory signature) external {
        OpenCohortAirdropConfig memory config = openCohortAirdropConfig();
        require(config.signer != address(0));

        bytes32 hash = keccak256(abi.encode("OpenCohort:Identity", cohort(), getChainId(), uniqueKey, beneficiary));
        if(config.signer.code.length == 0) {
            require(signature.length == 65);

            bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(hash);
            require(config.signer == ECDSA.recover(signingHash, signature));
        }
        else require(IERC1271(config.signer).isValidSignature(hash, signature) == IERC1271.isValidSignature.selector);

        _claim(config, index, uniqueKey, weight, proof, beneficiary);
    }

    function _claim(OpenCohortAirdropConfig memory config, uint256 index, address uniqueKey, uint256 weight, bytes32[] calldata proof, address beneficiary) internal {
        require(config.claimableTime <= block.timestamp);

        ICohort Cohort = ICohort(cohort());

        CohortMetadata memory cohortMetadata_;
        if(config.rewardType == RewardType.Unit){
            cohortMetadata_ = Cohort.metadata(cohortId());
            if(balanceOf(uniqueKey) == 0) _mint(uniqueKey, totalSupply() + 1);
        }
        else{
            cohortMetadata_ = cohortMetadata();
            if(isClaimed(index)) revert AlreadyClaimed();
            _setClaimed(index);
            _mint(uniqueKey, index + 1);
        }
        require(cohortMetadata_.merkleRoot != 0);

        bytes32 node = keccak256(abi.encodePacked(index, uniqueKey, weight));
        if(!MerkleProof.verify(proof, cohortMetadata_.merkleRoot, node)) revert InvalidProof();

        uint256 amount;
        if(config.rewardType == RewardType.Weight) amount = (config.totalAmount * weight) / cohortMetadata_.totalWeight;
        else if(config.rewardType == RewardType.Count) amount = config.totalAmount / cohortMetadata_.totalCount;
        else if(config.rewardType == RewardType.Constant) amount = config.amountPer;
        else if(config.rewardType == RewardType.Unit) amount = (config.amountPer * weight) - _claimedAmount[uniqueKey];
        else revert("Invalid RewardType");

        require(amount != 0);
        _claimedAmount[uniqueKey] += amount;

        CohortGrant memory grant = cohortGrant();
        if(grant.rate != 0){
            uint256 grantAmount = (amount * grant.rate) / cohortGrantRateDenominator();
            IERC20(config.token).safeTransfer(grant.grantee, grantAmount);
            amount = amount - grantAmount;
        }
        IERC20(config.token).safeTransfer(beneficiary, amount);

        emit Claimed(index, uniqueKey, weight, amount, beneficiary);
    }

    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
