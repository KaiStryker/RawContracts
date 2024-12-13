// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import './ERC-2981/ERC2981ContractWideRoyalties.sol';

contract CuriosERC721LimitedEdition is 
    ERC721Upgradeable,
    ERC2981ContractWide,
    OwnableUpgradeable, 
    PausableUpgradeable, 
    AccessControlUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Counter to keep track of token IDs
    CountersUpgradeable.Counter internal ids;

    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Total supply of tokens for this edition
    uint256 public totalSupply;

    // Base URI for token metadata
    string private baseURI;

    // URI for storefront metadata
    string private storeFrontURI;

    // Indicator to check if this is the base contract
    bool baseContract;

    // Events to track key actions
    event Created(address account, uint256 id);
    event CreatedBatch(address account, uint256 FirstMintedId, uint256 LastMintedId);
    event Deleted(uint256 id);
    event DeletedBatch(uint256[] ids);
    event TransferredBatch(address from, address[] to, uint256[] ids);

    /**
     * @dev Constructor to mark this contract as a base contract
     */
    constructor() { 
        baseContract = true; 
    }

    /**
     * @dev Initializes the limited edition contract with key parameters.
     */
    function initializeLimitedEdition(
        address _newOwner,
        address _minter, 
        address _royaltyRecipient,
        string calldata _name,
        string calldata _symbol, 
        string calldata _baseURI,
        uint256 _totalSupply,
        uint256 royaltyAmount
    ) 
        external
        initializer
        returns (bool)
    {
        require(!baseContract, "Base contract cannot be initialized"); // Ensure this is not the base contract
        __Ownable_init(); // Initialize Ownable contract
        __ERC721_init(_name, _symbol); // Initialize ERC721 with name and symbol
        __AccessControl_init(); // Initialize Access Control

        transferOwnership(_newOwner); // Transfer ownership to the new owner

        _setupRole(DEFAULT_ADMIN_ROLE, _newOwner); // Assign admin role to new owner
        _setupRole(MINTER_ROLE, _newOwner); // Assign minter role to new owner
        _setupRole(MINTER_ROLE, _minter); // Assign minter role to specified minter
        
        _setRoyalties(_royaltyRecipient, royaltyAmount); // Set royalty information

        _setBaseURI(_baseURI); // Set base URI for token metadata
        _setId(); // Initialize the token ID counter

        totalSupply = _totalSupply; // Set the total supply for the edition

        return true; // Return true on successful initialization
    }  

    /**
     * @dev Creates a new token and mints it to the specified account.
     */
    function createToken(
        address account 
    ) 
        external
        onlyRole(MINTER_ROLE)  
        returns (uint256 id) 
    {
        require(ids.current() <= totalSupply, "ERC721LimitedEdition: NFT token limit reached"); // Check if total supply is reached

        uint256 _id = ids.current(); // Get current token ID
        ids.increment(); // Increment the token ID counter
        _safeMint(account, _id); // Mint the token safely to the account
        emit Created(account, _id); // Emit event for token creation
        return _id; // Return the new token ID
    }

    /**
     * @dev Creates multiple tokens and mints them to the specified account.
     */
    function createTokens(
        address account,
        uint256 numberOfTokens
    ) 
        external
        onlyRole(MINTER_ROLE)  
        returns (uint256 LastId) 
    {
        require(ids.current() <= totalSupply, "ERC721LimitedEdition: NFT token limit reached"); // Check if total supply is reached
        
        uint256 i = 0;
        uint256 _id;
        uint256 FirstMintedId = ids.current(); // Store the first minted token ID

        while (gasleft() > 50000 && i < numberOfTokens && ids.current() <= totalSupply){  
            _id = ids.current(); // Get current token ID
            _safeMint(account, _id); // Mint the token to the specified account
            ids.increment(); // Increment token ID counter
            i++;         
        }

        uint256 LastMintedId = ids.current() - 1; // Get the last minted token ID

        emit CreatedBatch(account, FirstMintedId, LastMintedId); // Emit event for batch token creation
        return LastMintedId; // Return the last minted token ID
    }

    /**
     * @dev Deletes a token if the caller is the owner or an admin.
     */
    function deleteToken(uint256 id) external {
        require(
            _msgSender() == ownerOf(id) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Must be owner of Token or Admin to delete Token"
        );

        _burn(id); // Burn the token
        emit Deleted(id); // Emit event for token deletion
    }

    /**
     * @dev Deletes multiple tokens if the caller is an admin.
     */
    function deleteTokens(uint256[] calldata _ids) external onlyRole(DEFAULT_ADMIN_ROLE){

        for(uint256 i = 0; i < _ids.length; i++){ // Loop through the token IDs
            _burn(_ids[i]); // Burn each token
        }

        emit DeletedBatch(_ids); // Emit event for batch deletion
    }

    /**
     * @dev Transfers multiple tokens to multiple addresses.
     */
    function transferBatch(address[] calldata _accounts, uint256[] calldata _ids) external {
        require(_accounts.length == _ids.length, "array lengths aren't equal"); // Ensure the array lengths match

        for(uint256 i = 0; i < _accounts.length; i++){ // Loop through accounts and IDs
            safeTransferFrom(_msgSender(), _accounts[i], _ids[i]); // Transfer each token to the specified account
        }

        emit TransferredBatch(_msgSender(), _accounts, _ids); // Emit event for batch transfer
    }

    /**
     * @dev Pauses all token transfers.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause(); // Pause all transfers
    }

    /**
     * @dev Unpauses all token transfers.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause(); // Unpause all transfers
    }

    /**
     * @dev Sets the base URI for token metadata.
     */
    function setBaseURI(string memory _baseURI) external onlyRole(MINTER_ROLE) {
        _setBaseURI(_baseURI); // Set the base URI
    }

    /**
     * @dev Sets royalty information for the contract.
     */
    function setRoyaltyInfo(address recipient, uint256 _royaltyAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoyalties(recipient, _royaltyAmount); // Set royalty info for the contract
    }
}