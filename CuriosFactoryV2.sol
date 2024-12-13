// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.4;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/Clones.sol';

interface Initializer {
    function initializeOpenEdition(
        address _newOwner,
        address _minter,
        string calldata _name, 
        string calldata _symbol, 
        string calldata _baseURI
    ) 
    external 
    returns (bool);

    function initializeLimitedEdition(
        address _newOwner,
        address _minter,
        string calldata _name, 
        string calldata _symbol, 
        string calldata _baseURI,
        uint256 _totalSupply
    ) 
    external
    returns (bool);
}

contract CuriosFactory is AccessControl{

    bytes32 public constant CONTRACT_CREATOR_ROLE = keccak256("CONTRACT_CREATOR_ROLE"); // Role for contract creators
    
    // Arrays to store deployed contract addresses
    address[] internal ERC721OpenEditionContracts;
    address[] internal ERC721LimitedEditionContracts;

    address[] internal ERC721aOpenEditionContracts;
    address[] internal ERC721aLimitedEditionContracts;

    // Addresses for implementation contracts
    address public openEditionImplementation;
    address public limitedEditionImplementation;

    address public openEditionERC721aImplementation;
    address public limitedEditionERC721aImplementation;

    // Events to track contract creation
    event ERC721OpenEditionContractCreated(string indexed ContractName, address indexed ERC721OpenContract);
    event ERC721LimitedEditionContractCreated(string indexed ContractName, address indexed ERC721LimitedContract);

    event ERC721aOpenEditionContractCreated(string indexed ContractName, address indexed ERC721OpenContract);
    event ERC721aLimitedEditionContractCreated(string indexed ContractName, address indexed ERC721LimitedContract);

    /**
     * @dev Constructor to set up admin and contract creator roles, and define implementations.
     */
    constructor(
        address _admin, 
        address _contract_creator,
        address _openEdition,
        address _limitedEdition,
        address _openEditionERC721a,
        address _limitedEditionERC721a
    )  
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin); // Set admin role
        _setupRole(CONTRACT_CREATOR_ROLE, _contract_creator); // Set contract creator role
        _setupRole(CONTRACT_CREATOR_ROLE, _admin); // Admin is also a contract creator

        _setOpenEditionImplementation(_openEdition); // Set open edition implementation
        _setLimitedEditionImplementation(_limitedEdition); // Set limited edition implementation

        _setOpenEditionERC721aImplementation(_openEditionERC721a); // Set open edition ERC721a implementation
        _setLimitedEditionERC721aImplementation(_limitedEditionERC721a); // Set limited edition ERC721a implementation
    }

    /**
     * @dev Sets the open edition implementation address.
     */
    function _setOpenEditionImplementation(address _openEdition) internal {
        require(_openEdition != address(0), "Address cannot be zero address"); // Ensure the address is not zero
        openEditionImplementation = _openEdition; // Set the open edition implementation address
    }

    /**
     * @dev Sets the limited edition implementation address.
     */
    function _setLimitedEditionImplementation(address _limitedEdition) internal {
        require(_limitedEdition != address(0), "Address cannot be zero address"); // Ensure the address is not zero
        limitedEditionImplementation = _limitedEdition; // Set the limited edition implementation address
    }

    /**
     * @dev Sets the open edition ERC721a implementation address.
     */
    function _setOpenEditionERC721aImplementation(address _openEdition) internal {
        require(_openEdition != address(0), "Address cannot be zero address"); // Ensure the address is not zero
        openEditionERC721aImplementation = _openEdition; // Set the open edition ERC721a implementation address
    }

    /**
     * @dev Sets the limited edition ERC721a implementation address.
     */
    function _setLimitedEditionERC721aImplementation(address _limitedEdition) internal {
        require(_limitedEdition != address(0), "Address cannot be zero address"); // Ensure the address is not zero
        limitedEditionERC721aImplementation = _limitedEdition; // Set the limited edition ERC721a implementation address
    }

    /**
     * @dev Returns all ERC721 open edition contracts.
     */
    function getERC721OpenEditionContracts() external view returns(address[] memory) {
        return ERC721OpenEditionContracts; // Return the list of open edition contracts
    }

    /**
     * @dev Returns all ERC721 limited edition contracts.
     */
    function getERC721LimitedEditionContracts() external view returns(address[] memory) {
        return ERC721LimitedEditionContracts; // Return the list of limited edition contracts
    }   

    /**
     * @dev Returns the most recently created open edition contract.
     */
    function getLastOpenEditionContract() external view returns(address) {
        return ERC721OpenEditionContracts[ERC721OpenEditionContracts.length - 1]; // Return the last contract in the list
    }

    /**
     * @dev Returns the most recently created limited edition contract.
     */
    function getLastLimitedEditionContract() external view returns(address) {
        return ERC721LimitedEditionContracts[ERC721LimitedEditionContracts.length - 1]; // Return the last contract in the list
    }  

    /**
     * @dev Returns the most recently created open edition ERC721a contract.
     */
    function getLastOpenEditionERC721aContract() external view returns(address) {
        return ERC721aOpenEditionContracts[ERC721aOpenEditionContracts.length - 1]; // Return the last contract in the list
    }

    /**
     * @dev Returns the most recently created limited edition ERC721a contract.
     */
    function getLastLimitedEditionERC721aContract() external view returns(address) {
        return ERC721aLimitedEditionContracts[ERC721aLimitedEditionContracts.length - 1]; // Return the last contract in the list
    } 
     
    /**
    * @dev Helper function to generate a new deterministic salt.
    */
    function getNewSalt(
        bytes20 _salt, 
        address _newOwner,
        address _minter, 
        string calldata _name, 
        string calldata _symbol, 
        string calldata _baseURI,
        uint256 _totalSupply
    ) 
        internal pure 
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(keccak256(abi.encodePacked(_newOwner, _minter, _name, _symbol, _baseURI, _totalSupply)), _salt));
    }
}