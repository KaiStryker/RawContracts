// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MatteBlackCard is ERC1155, Ownable, AccessControl {
    
    // Address where minted tokens are sent for custody
    address immutable private custodyWallet;
    
    // Boolean flag to track if black cards have been minted
    bool public blackCardsMinted;
    
    // Contract-level metadata URI
    string public contractURI;

    // Name and symbol for the token collection
    string public constant name = "MATTE Black Card";
    string public constant symbol = "BLACKCARD";

    // Custom errors for more gas-efficient revert reasons
    error OnlyMinterCanMint();
    error AllBlackCardsMinted();
    error ZeroAddressNotAllowed();

    // Role definition for MINTER_ROLE
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Constructor to set up key roles and wallet addresses.
     */
    constructor(
        string memory uri,
        string memory _contractURI, 
        address _custodyWallet,
        address admin,
        address minter
    ) 
        ERC1155(uri) 
    {
        if(_custodyWallet == address(0x0)) revert ZeroAddressNotAllowed(); // Ensure custody wallet is not zero address
    
        _setupRole(DEFAULT_ADMIN_ROLE, admin); // Assign admin role to admin address
        _setupRole(MINTER_ROLE, minter); // Assign minter role to minter address
        _transferOwnership(_custodyWallet); // Transfer ownership to the custody wallet

        custodyWallet = _custodyWallet; // Set custody wallet address
        contractURI = _contractURI; // Set the contract URI for metadata
    }

    /**
     * @dev Mints black cards and sends them to the custody wallet.
     * Can only be called by an address with the MINTER_ROLE.
     */
    function mintBlackCards() external {
        if(!hasRole(MINTER_ROLE, _msgSender())) revert OnlyMinterCanMint(); // Ensure only minters can call this function
        if(blackCardsMinted) revert AllBlackCardsMinted(); // Ensure black cards are only minted once
        
        blackCardsMinted = true; // Set flag to true to prevent future minting
        _mint(custodyWallet, 1, 333, ""); // Mint 333 tokens of ID 1 to the custody wallet
    }

    /**
     * @dev Returns whether the contract supports a given interface ID.
     * Supports AccessControl and ERC1155 interfaces.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId); // Check parent contracts for support
    }
}
