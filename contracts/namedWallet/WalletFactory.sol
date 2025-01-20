pragma solidity ^0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "./NamedWallet.sol";

interface IProxy {
    function owner() external view returns (address);
    function signer() external view returns (address);
    function getChain() external view returns (string memory);
    function getAdmin() external view returns (address);
    function getImplementation() external view returns (address);
}

interface INamedWallet {
    function initialize(WalletInfo calldata walletInfo, address _openNameTag, address _signer) external;
    function activateWallet(address _signer, address _owner) external;
}

interface IOpenIdentityRegistry {
    function isUsedHash(bytes32) external view returns (bool);
    function isRevokedBeneficiary(address, address) external view returns (bool);
    function revokeBeneficiary(address, bool) external;
    function revokeBeneficiaryBySignature(address, address, bool, uint256, bytes calldata) external;
}

contract WalletFactory{

    // isDeployed로
    mapping(address => bool) public isDeployed;

    mapping(address => address[]) public walletList;
    mapping(address => uint) public walletCount;
    address public implementation;
    address public openNameTag;
    address public cohort;
    address public identityRegistry;

    event WalletCreated(address wallet, address signer, address virtualAddress, uint256 rate);
    event WalletActivated(address wallet, address owner);

    function version() public pure returns (string memory){
        return "factory250110";
    }

    constructor(address openNameTag_, address cohort_, address identityRegistry_) {
        implementation = address(new NamedWallet());
        openNameTag = openNameTag_;
        cohort = cohort_;
        identityRegistry = identityRegistry_;
    }

    function computeAddress(address signer, address virtualAddress) public view returns (address) {
        bytes32 salt = getSalt(signer, virtualAddress);
        return Create2.computeAddress(bytes32(salt), keccak256(abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation,"")
        )));
    }

    function getSalt(address signer, address virtualAddress) public pure returns (bytes32) {
        return keccak256(abi.encode(signer, virtualAddress));
    }

    function deployWallet(address virtualAddress, WalletInfo memory walletInfo, string[] calldata keys, string[] calldata values) public returns (address) {
        address signer = msg.sender;

        address proxy;
        {
            bytes32 salt = getSalt(signer, virtualAddress);
            proxy = payable(new ERC1967Proxy{salt : bytes32(salt)}(
                implementation,""
            ));
        }

        NamedWallet(payable(proxy)).initialize(walletInfo, openNameTag, signer);
        NamedWallet(payable(proxy)).addPropertyBatch(keys, values);

        isDeployed[proxy] = true;

        walletList[signer].push(virtualAddress);
        walletCount[signer]++;
        emit WalletCreated(proxy, signer, virtualAddress, walletInfo.rate);
        return proxy;
    }

    function getDataHash(address virtualAddress, address owner) public view returns (bytes32) {
        return keccak256(abi.encode("OpenCohort:Identity", cohort, getChainId(), virtualAddress, owner));
    }

    function activateWallet(
        address signer,
        address virtualAddress,
        address owner,
        bytes calldata signature
    ) public {
        address proxy = computeAddress(signer, virtualAddress);
        require(isDeployed[proxy] == true, "Not deployed");

        require(IProxy(proxy).signer() == signer, "Invalid signer");
        bytes32 dataHash = getDataHash(virtualAddress, owner);

        if(signer.code.length == 0){
            require(signature.length == 65, "Invalid signature length");

            bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
            require(signer == ECDSA.recover(signingHash, signature), "Invalid signature");
        }
        else require(IERC1271(signer).isValidSignature(dataHash, signature) == IERC1271.isValidSignature.selector, "Invalid signature");
        
        if(identityRegistry != address(0)) require(!IOpenIdentityRegistry(identityRegistry).isRevokedBeneficiary(signer, owner));

        INamedWallet(proxy).activateWallet(signer, owner);
        emit WalletActivated(proxy, owner);
    }

    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
