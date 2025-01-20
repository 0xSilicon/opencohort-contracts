pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

struct WalletInfo{
    string name;
    string image;
    string description;
    uint256 rate;
}

interface IOpenNameTag {
    struct NameTagMetadata {
        string name;
        string description;
        string image;
    }

    function mint(NameTagMetadata calldata, string[] calldata, string[] calldata) external;
    function setNameTagMetadata(NameTagMetadata calldata) external;
    function addPropertyBatch(string[] calldata, string[] calldata) external;
    function removeProperty(string calldata) external;
}

contract NamedWallet is Initializable, UUPSUpgradeable, ReentrancyGuard{
    using SafeERC20 for IERC20;

    address public factory;
    address public signer;
    address public owner;
    uint256 public rate; // 10000: 100%
    address public openNameTag;
    bool private _isUpgradeCalled = false;

    event InitializedInfo(string name, string image, string description, uint256 rate, address openNameTag, address signer);
    event ChangeInfo(string name, string image, string description);
    event ChangeTaxRate(uint256 rate);
    event TransferByOwner(address indexed token, address indexed to, uint256 value);
    event OwnershipTransferred(address indexed signer, address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner(){
        require(msg.sender == owner, "Only owner can call this function!");
        _;
    }

    modifier onlySigner(){
        require(msg.sender == signer, "Only signer can call this function!");
        _;
    }

    modifier onlySignerOrFactory(){
        require(msg.sender == signer || msg.sender == factory, "Only signer or factory can call this function!");
        _;
    }

    modifier onlyFactory(){
        require(msg.sender == factory, "Only factory can call this function!");
        _;
    }

    function version() public pure returns (string memory){
        return "wallet250116";
    }

    constructor() {
        _disableInitializers();
    }
    
    function initialize(WalletInfo calldata walletInfo, address _openNameTag, address _signer) public initializer{
        require(walletInfo.rate <= 10000, "Invalid rate");
        signer = _signer;
        factory = msg.sender;
        rate = walletInfo.rate;
        openNameTag = _openNameTag;
        IOpenNameTag.NameTagMetadata memory nameTagMetadata = IOpenNameTag.NameTagMetadata(walletInfo.name, walletInfo.description, walletInfo.image);
        mintNameTag(nameTagMetadata, new string[](0), new string[](0));
        emit InitializedInfo(walletInfo.name, walletInfo.image, walletInfo.description, walletInfo.rate, _openNameTag, _signer);
    }

    function changeTaxRate(uint256 rate_) public onlySigner{
        require(rate_ <= 10000, "Invalid rate");
        rate = rate_;
        emit ChangeTaxRate(rate_);
    }

    function changeInfo(string memory _name, string memory _image, string memory _description) public onlySigner{
        IOpenNameTag.NameTagMetadata memory nameTagMetadata = IOpenNameTag.NameTagMetadata(_name, _description, _image);
        IOpenNameTag(openNameTag).setNameTagMetadata(nameTagMetadata);
        emit ChangeInfo(_name, _image, _description);
    }

    function mintNameTag(IOpenNameTag.NameTagMetadata memory nameTagMetadata, string[] memory keys, string[] memory values) internal onlyFactory {
        IOpenNameTag(openNameTag).mint(nameTagMetadata, keys, values);
    }

    function addPropertyBatch(string[] calldata keys, string[] calldata values) external onlySignerOrFactory {
        IOpenNameTag(openNameTag).addPropertyBatch(keys, values);
    }

    function removeProperty(string calldata key) external onlySigner {
        IOpenNameTag(openNameTag).removeProperty(key);
    }

    function activateWallet(address _signer, address _owner) public onlyFactory {
        require(signer == _signer, "Invalid signer");
        require(owner == address(0), "Already activated");
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
        emit OwnershipTransferred(_signer, address(0), _owner);
    }

    function transferTo(address to, uint256 amount) public payable onlyOwner nonReentrant{
        uint256 tax = amount * rate / 10000;
        amount -= tax;
        require(to != address(0), "Invalid address");
        bool success;
        if(amount > 0){
            (success, ) = payable(to).call{value: amount}("");
            require(success, "Transfer failed");
            emit TransferByOwner(address(0), to, amount);
        }
        if(tax > 0){
            (success, ) = payable(signer).call{value: tax}("");
            require(success, "Transfer failed");
            emit TransferByOwner(address(0), signer, tax);
        }
    }

    function transferTokenTo(address token, address to, uint256 amount) public onlyOwner nonReentrant{
        uint256 tax = amount * rate / 10000;
        amount -= tax;
        require(to != address(0), "Invalid address");
        if(amount > 0){
            IERC20(token).safeTransfer(to, amount);
            emit TransferByOwner(token, to, amount);
        }
        if(tax > 0){
            IERC20(token).safeTransfer(signer, tax);
            emit TransferByOwner(token, signer, tax);
        }
    }

    function getUpdateDataHash(address newImplementation, bytes memory data) public view returns (bytes32) {
        return keccak256(abi.encode("WalletUpgrade", signer, getChainId(), newImplementation, data));
    }

    // update implementation use signer's signature
    function upgradeImplementation(address newImplementation, bytes memory data, bytes calldata signature) public {
        _isUpgradeCalled = true;
        bytes32 dataHash = getUpdateDataHash(newImplementation, data);
        if(signer.code.length == 0){
            require(signature.length == 65, "Invalid signature length");

            bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(dataHash);
            require(signer == ECDSA.recover(signingHash, signature), "Invalid signature");
        }
        else require(IERC1271(signer).isValidSignature(dataHash, signature) == IERC1271.isValidSignature.selector, "Invalid signature");

        upgradeToAndCall(newImplementation, data);
        _isUpgradeCalled = false;
    }

    // function upgradeImplementation(bytes memory signature, address newImplementation, bytes memory data) public {}

    function _authorizeUpgrade(address newImplementation) internal override view {
        require(_isUpgradeCalled == true, "Call upgradeImplementation");
        if(owner != address(0)){
            require(msg.sender == owner, "Unauthorized");
        } else {
            require(msg.sender == signer, "Unauthorized");
        }
        require(newImplementation != address(0), "Invalid address");
    }

    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }

    receive () external payable { }
    fallback () external payable { }
}
