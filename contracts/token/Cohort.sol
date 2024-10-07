// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import "../interface/IERC5192.sol";
import "../interface/ICohort.sol";

contract Cohort is ICohort, Ownable, UUPSUpgradeable, ERC165, IERC5192 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 _tokenId);

    string private _name;
    string private _symbol;

    address[] internal _tokens = [address(0x0)];
    mapping(address => uint256) private _balances;

    mapping(uint256 => uint256) private _metadataNonce;
    mapping(uint256 => CohortMetadata) private _metadata;

    mapping(uint256 => uint256) public snapShotCount;
    mapping(uint256 => mapping(uint256 => uint256)) public snapShotTime;
    mapping(uint256 => mapping(uint256 => CohortMetadata)) public snapShotMetadata;

    mapping(uint256 => GrantConfig) private _grant;

    event SetCohortMetadata(uint256 tokenId, uint256 nonce, CohortMetadata metadata, uint256 snapShotTime);
    event SetCohortGrant(uint256 tokenId, GrantConfig cohortGrant);
    
    error BalanceQueryForZeroAddress();
    error OwnerIndexOutOfBounds();
    error URIQueryForNonExistentToken();
    error OwnerQueryForNonExistentToken();
    error MintToTheZeroAddress();

    constructor() Ownable(address(0xdead)) { _name = "CohortImplementation"; }

    function initialize(address owner_, string memory name_, string memory symbol_) external {
        require(bytes(_name).length == 0);

        if(owner() != address(0)) require(msg.sender == owner());
        else _transferOwnership(owner_);

        require(bytes(name_).length != 0);
        _name = name_;

        require(bytes(symbol_).length != 0);
        _symbol = symbol_;

        _tokens.push(address(0));
    }

    function version() external pure returns (string memory) {
        return "Cohort240924";
    }

    //////////////////////////////////////////////////////////////////
    // ERC5192 Interface
    function locked(uint256) external pure returns (bool) { return true; }
    //////////////////////////////////////////////////////////////////

    modifier onlyAdmin(uint256 tokenId) {
        require(msg.sender == owner() || msg.sender == Cohort.ownerOf(tokenId));
        _;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            interfaceId == bytes4(0x49064906) ||
            super.supportsInterface(interfaceId);
    }

    function totalMinted() public view returns (uint256) {
        return _tokens.length - 1;
    }

    function totalSupply() public view returns (uint256) {
        return totalMinted();
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        if (balanceOf(owner) <= index) revert OwnerIndexOutOfBounds();
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == owner) {
                if (currentIndex == index) {
                    return i;
                }
                currentIndex += 1;
            }
        }
        revert OwnerIndexOutOfBounds();
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert BalanceQueryForZeroAddress();
        }
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _tokens[tokenId];
        if(owner == address(0)) {
            revert OwnerQueryForNonExistentToken();
        }

        return owner;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        if(!_exists(tokenId)) {
            revert URIQueryForNonExistentToken();
        }

        return _metadata[tokenId].tokenURI;
    }

    function baseURI() public pure returns (string memory) {
        return "";
    }

    function cohortType(uint256 tokenId) public view returns (CohortType) {
        require(_exists(tokenId));
        return _metadata[tokenId].cohortType;
    }

    function grant(uint256 tokenId) public view returns (GrantConfig memory) {
        require(_exists(tokenId));
        return _grant[tokenId];
    }

    function MAX_GRANT_RATE() public pure returns (uint256) {
        return 0;
    }

    function GRANT_RATE_DENOMINATOR() public pure returns (uint256) {
        return 10000;
    }

    function metadata(uint256 tokenId) public view returns (CohortMetadata memory) {
        require(_exists(tokenId));
        return _metadata[tokenId];
    }

    function metadataNonce(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId));
        return _metadataNonce[tokenId];
    }

    function getLastSnapShotTime(uint256 tokenId) public view returns (uint256) {
        require(tokenId != 0);
        uint256 index = snapShotCount[tokenId];
        if (index == 0) {
            return 0;
        }

        return snapShotTime[tokenId][index -1];
    }

    function getExactTimeSnapShot(uint256 tokenId, uint256 timestamp) public view returns (CohortMetadata memory) {
        require(tokenId != 0);

        CohortMetadata memory cohortMetadata;
        uint256 index = snapShotCount[tokenId];
        if (index == 0) return cohortMetadata;
        if (snapShotTime[tokenId][0] > timestamp) return cohortMetadata;
        if (snapShotTime[tokenId][index - 1] < timestamp) return cohortMetadata;

        if (snapShotTime[tokenId][index - 1] == timestamp) return snapShotMetadata[tokenId][index - 1];

        uint256 lower = 0;
        uint256 upper = index - 1;
        while (upper > lower) {
            uint256 center = upper - ((upper - lower) / 2);
            uint256 centerTime = snapShotTime[tokenId][center];

            if (centerTime == timestamp) {
                return snapShotMetadata[tokenId][center];
            } else if (centerTime < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }

        return cohortMetadata;
    }

    function getSnapShot(uint256 tokenId, uint256 timestamp) public view returns (CohortMetadata memory) {
        require(timestamp < block.timestamp);
        require(tokenId != 0);

        CohortMetadata memory cohortMetadata;
        uint256 index = snapShotCount[tokenId];
        if (index == 0) {
            return cohortMetadata;
        }

        if (snapShotTime[tokenId][index - 1] <= timestamp) {
            return snapShotMetadata[tokenId][index - 1];
        }

        if (snapShotTime[tokenId][0] > timestamp) {
            return cohortMetadata;
        }

        uint256 lower = 0;
        uint256 upper = index - 1;
        while (upper > lower) {
            uint256 center = upper - ((upper - lower) / 2);
            uint256 centerTime = snapShotTime[tokenId][center];

            if (centerTime == timestamp) {
                return snapShotMetadata[tokenId][center];
            } else if (centerTime < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }

        return snapShotMetadata[tokenId][lower];
    }

    function addSnapShot(uint256 tokenId, uint256 timestamp) private {
        require(tokenId != 0);
        CohortMetadata memory cohortMetadata = metadata(tokenId);

        uint256 index = snapShotCount[tokenId];
        if(index != 0) require(snapShotTime[tokenId][index - 1] < timestamp);

        snapShotTime[tokenId][index] = timestamp;
        snapShotMetadata[tokenId][index] = cohortMetadata;
        snapShotCount[tokenId] = snapShotCount[tokenId] + 1;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokens[tokenId] != address(0);
    }

    function _mint(address to, CohortMetadata memory cohortMetadata) internal virtual returns (uint256) {
        if (to == address(0)) {
            revert MintToTheZeroAddress();
        }
        
        uint256 tokenId = _tokens.length;
        _balances[to] += 1;
        _tokens.push(to);
        emit Transfer(address(0), to, tokenId);
        emit Locked(tokenId);

        _metadata[tokenId] = cohortMetadata;
        emit MetadataUpdate(tokenId);

        return tokenId;
    }
    
    function mint(CohortMetadata memory cohortMetadata) external returns (uint256) {
        require(cohortMetadata.cohortType != CohortType.None);

        if(cohortMetadata.merkleRoot != 0) {
            require(cohortMetadata.totalWeight != 0);
            require(cohortMetadata.totalCount != 0);
            require(bytes(cohortMetadata.prover).length != 0);
        }

        uint256 parentCohortLength = cohortMetadata.parentCohort.length;
        if(parentCohortLength != 0){
            for(uint256 i = 0; i < parentCohortLength; i++){
                uint256 parentId = cohortMetadata.parentCohort[i];
                require(_exists(parentId));
                for(uint256 j = i + 1; j < parentCohortLength; j++){
                    require(parentId != cohortMetadata.parentCohort[j]);
                }
            }
        }

        uint256 tokenId = _mint(msg.sender, cohortMetadata);
        addSnapShot(tokenId, block.timestamp);
        emit SetCohortMetadata(tokenId, 0, cohortMetadata, block.timestamp);

        return tokenId;
    }

    function setTokenURI(uint256 tokenId, string calldata tokenURI_) external onlyAdmin(tokenId) {
        require(_exists(tokenId));
        _metadata[tokenId].tokenURI = tokenURI_;

        emit MetadataUpdate(tokenId);
    }

    function setCohortGrant(uint256 tokenId, GrantConfig calldata cohortGrant) external onlyAdmin(tokenId) {
        require(_exists(tokenId));
        require(cohortGrant.rate <= MAX_GRANT_RATE());
        require(cohortGrant.grantee != address(0));
        _grant[tokenId] = cohortGrant;

        emit SetCohortGrant(tokenId, cohortGrant);
    }

    function rollupWithSignature(
        uint256 tokenId,
        CohortMetadata memory cohortMetadata,
        uint256 timestamp,
        bytes calldata signature
    ) external {
        require(timestamp <= block.timestamp);
        require(getLastSnapShotTime(tokenId) < timestamp);
        require(_exists(tokenId));
        require(cohortMetadata.merkleRoot != 0);
        require(cohortMetadata.totalWeight != 0);
        require(cohortMetadata.totalCount != 0);
        require(bytes(cohortMetadata.prover).length != 0);

        uint256 nonce = _metadataNonce[tokenId] + 1;
        bytes32 hash = keccak256(abi.encode("OpenCohort:Rollup", address(this), getChainId(), tokenId, nonce, cohortMetadata.merkleRoot, cohortMetadata.totalWeight, cohortMetadata.totalCount, cohortMetadata.prover, timestamp));

        address owner = ownerOf(tokenId);
        if(owner.code.length == 0){
            require(signature.length == 65);

            bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(hash);
            require(owner == ECDSA.recover(signingHash, signature));
        }
        else require(IERC1271(owner).isValidSignature(hash, signature) == IERC1271.isValidSignature.selector);

        _metadataNonce[tokenId] = nonce;
        _metadata[tokenId].merkleRoot = cohortMetadata.merkleRoot;
        _metadata[tokenId].totalWeight = cohortMetadata.totalWeight;
        _metadata[tokenId].totalCount = cohortMetadata.totalCount;
        _metadata[tokenId].prover = cohortMetadata.prover;

        addSnapShot(tokenId, timestamp);

        emit SetCohortMetadata(tokenId, nonce, _metadata[tokenId], timestamp);
    }

    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
