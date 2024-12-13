// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interface/IWETH.sol";

contract MATTEBADGE001 is ERC721A, PaymentSplitter, Ownable {
    using Strings for uint256;
    using Address for address payable;

    uint8 constant MAX_MINTS_PER_ADDRESS = 3;
    uint8 constant MAX_MINTS_PER_BATCH = 3;
    uint64 constant MINT_FEE = .05 ether;

    string public baseURI;
    string public contractURI;
    bool public collectionRevealed;

    address private constant SETTER = 0x4f7D41A72e8DdD1Ef4cc822d7193860af02e4Efd;
    address private constant ADMIN = 0xc5b561fEA724f3D673788E644c93DC2cfae3347e;

    bytes32 public merkleRoot;
    uint256 public mintEndTime;

    error OnlySetterCanAccess();
    error OnlyAdminCanAccess();
    error MintingHasConcluded();
    error MaxMintForAddressExceeded();
    error MaxMintForWhitelistExceeded();
    error MaxMintPerBatchExceeded();
    error CollectionRevealedAlready();
    error InvalidFee();

    mapping(address => uint256) public mintsPerAddress;
    mapping(address => bool) public mintedViaWhitelist;

    constructor(
        string memory _baseURI_, 
        string memory _contractURI,
        bytes32 _merkleRoot,
        address[] memory payees, 
        uint256[] memory shares_
    )
        ERC721A("MATTE Badge 001", "BADGE001")
        PaymentSplitter(payees, shares_) 
    {
        baseURI = _baseURI_;
        contractURI = _contractURI;
        merkleRoot = _merkleRoot;
        mintEndTime = block.timestamp + 4.5 days;
    }

    /**
     * @dev Mints a batch of tokens
     * Ensures minting does not exceed limits per batch and total allowed mints per address
     */
    function mint(uint256 quantity) external payable {
        if(block.timestamp > mintEndTime) revert MintingHasConcluded(); // Check if minting period has ended
        if(quantity > MAX_MINTS_PER_BATCH) revert MaxMintPerBatchExceeded(); // Check if quantity exceeds max per batch
        if(mintsPerAddress[_msgSender()] + quantity > MAX_MINTS_PER_ADDRESS) revert MaxMintForAddressExceeded(); // Check if total mints for address exceeds limit
        
        uint256 feeAmount = quantity * MINT_FEE; // Calculate total fee
        if(msg.value != feeAmount) revert InvalidFee(); // Check if correct fee is sent
        
        mintsPerAddress[_msgSender()] += quantity; // Update the toal mints for the address

        _safeMint(_msgSender(), quantity); // Mint the tokens to the sender's address
    }

    /**
     * @dev Reveals the colection updating the base URI
     * Can only be called vy the SETTER address and only once
     */
    function revealCollection(string memory newBaseURI) external {
        if(collectionRevealed) revert CollectionRevealedAlready(); // Check if the collection is already revealed
        if(SETTER != _msgSender()) revert OnlySetterCanAccess(); // Ensure only the SETTER address can call this
        collectionRevealed = true; // Mark the collection as revealed
        baseURI = newBaseURI; // Update the base URI
    }

    /**
     * @dev Allows whitelisted users to mint one token using a Merkel proof
     * Each whitelisted address can mint only once.
     */
    function whiteListMint(address account, bytes32[] calldata merkleProof) external{
        if(block.timestamp > mintEndTime) revert MintingHasConcluded(); // 
        if(mintedViaWhitelist[account]) revert MaxMintForWhitelistExceeded();
    
        bytes32 leaf = keccak256(abi.encodePacked(account)); // create leaf node for Merkle Tree

        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf), // Verify Merkle Proof
            "MerkleDistributor: Invalid proof."
        );

        mintedViaWhitelist[account] = true; // Mark address as haing minted via whitelist

        _safeMint(account, 1); // Mint one token to the whitelisted address
    }

    /**
     * @dev Mints tokens for a given address as an admin
     * Can only be called by the ADMIN address
     */
    function mintAsAdmin(address account, uint256 quantity) external {
        if(ADMIN != _msgSender()) revert OnlyAdminCanAccess(); // Ensure only the ADMIN address can call this
        mintsPerAddress[account] += quantity; // Update the total mints for the address
        _safeMint(account, quantity); // Mint the tokens to the specified address
    }

    /**
     * @dev Updates the Merkle root used the whitelist verification
     * Can only be called by SETTER address
     */
    function setMerkleRoot(bytes32 _merkleRoot) external {
        if(SETTER != _msgSender()) revert OnlySetterCanAccess(); // Ensure only the ADMIN address can call this
        merkleRoot = _merkleRoot; // Update the Merkle root
    }
    
    /**
     * @dev Extends the minting period by an additional 4 hours
     * Can only ve called by the SETTER address
     */
    function extendMintEndTime() external {
        if(SETTER != _msgSender()) revert OnlySetterCanAccess(); // Ensure only the ADMIN address can call this 
        mintEndTime = block.timestamp + 4 hours; // Extend the minting period by 4 hours
    }

    /**
     * @dev Releases funds to a given account
     * Calls the release function from PaymentSplitter
     */
    function releaseFunds(address payable account) external {
        super.release(account); // Call PaymentSPlitter release function
    }

    /**
     * @dev Mints a batch of tokens.
     * Ensures minting does not exceed limits per batch and total allowed mints per address.
     */
    function totalFundsReleased() external view returns (uint256){
        return totalReleased(); // Return total funds relesed from PaymentSplitter
    }

    /**
     * @dev Returns the URI for a given token ID
     * If the collection is not revealed, returns the base URI
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken(); // Ensure token exists 

        string memory baseURI_ = _baseURI(); // Get base URI

        if (!collectionRevealed) return baseURI_; // Return based URI if collection is not revealed
        return string(abi.encodePacked(baseURI_, tokenId.toString(), ".json")); //  Return full URI for revealed collection metadata
    }

    /**
     * @dev Returns the base URI of the collection
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}