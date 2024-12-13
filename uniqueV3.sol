// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
* This is the version of the contract we'd actually be deploying
*
* It gets rid of Ownable and replaces it with AccessControl for more flexibility with defining roles
* It also adds a rentrancy guard for protecting the buyMoment function from any rentrancy attacks
* AccessControlEnumerable allows for querying data about role members and the amount of members a role has
* If we stuck with the original AccessControl we would not have this feature available to us
*
* Another notable is that the "onlyOwner" modifier is replaced with "onlyRole(DEFAULT_ADMIN_ROLE)" which 
* accomplishes the same thing.
*
* As requested, a minter role was created and the "onlyRole(MINTER_ROLE)" was added on the createMoment(s)functions 
*/

contract UniqueV3 is ERC721URIStorageUpgradeable, UUPSUpgradeable, AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Address for royalty payments
    address payable internal royaltyOwner;
    
    // Counter to keep track of token IDs
    CountersUpgradeable.Counter internal ids;

    // Royalty rate for secondary sales
    uint256 internal rate;

    // Role definition for Minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Enum to track the status of a sale
    enum Stages {
        NotForSale,
        ForSale,
        SaleInProgress
    }

    // Structure for details about a sale
    struct Sale {
        Stages status;
        uint price;
        address buyer;
    }

    // Mapping to store information about each auction
    mapping(uint256 => Sale) internal auction;

    // List of authorized marketplace addresses
    address[] authorizedMarketplaces;

    // Events to track state changes
    event RoyaltyRateSet(uint256 rate);
    event RoyaltyOwnerSet(address newOwner);
    event Created(address account, uint256 id);
    event CreatedBatch(address account, uint256[] ids);
    event Deleted(uint256 id);
    event AuctionPrice(uint256 id, uint price);
    event Purchased(uint256 id, address buyer);
    event TransferredBatch(address operator, address from, address to, uint256[] ids);
    event ModifiedMarketplace(address[] list);
    event MarketplaceListCleared();

    /** 
    * @dev Initializes the contract and sets up roles and royalty configuration
    */
    function initialize(
        address payable _royaltyOwner, 
        uint256 _rate, 
        address _minter, 
        string memory _name, 
        string memory _symbol
    ) external initializer {
        __UUPSUpgradeable_init(); // Initialize upgradeability logic
        __ERC721URIStorage_init(); // Initialize ERC721 URI storage logic
        __ReentrancyGuard_init(); // Initialize reentrancy guard
        __AccessControl_init(); // Initialize access control
        __ERC721_init(_name, _symbol); // Initialize ERC721 token with name and symbol

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender()); // Assign role for ontract deployer
        _setupRole(MINTER_ROLE, _minter); // Assign minter role to specified address
        _setupRole(MINTER_ROLE, _msgSender()); // Assign minter role to deployer as well
        
        setRoyaltyOwner(_royaltyOwner); // Set intial royalty owner
        setRoyaltyRate(_rate); // Set initial royalty rate
    }

    /** 
    * @dev Returns the current contract version
    */
    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }   

    /** 
    * @dev Returns true if the contract support the given inteface ID
    */
    function supportsInterface(
        bytes4 interfaceId
    ) 
        public view virtual override(AccessControlEnumerableUpgradeable, ERC721Upgradeable) 
        returns (bool) 
    {
        return interfaceId == type(IERC721Upgradeable).interfaceId
        || super.supportsInterface(interfaceId);
    } 

    /** 
    * @dev Allows a user to buy a moment NFT that is for sale
    */
    function buyMoment(uint256 id) external virtual payable nonReentrant {
        require(
            msg.value >= auction[id].price,
            "Minimum purchase price not met"
        );
        require(
            auction[id].status == Stages.ForSale,
            "Moment not for sale"
        );
        
        auction[id].status = Stages.SaleInProgress; // update sale status 
        auction[id].price = msg.value; // Update sale price
        auction[id].buyer = _msgSender(); // Record buyer address
        safeTransferFrom(ownerOf(id), _msgSender(), id);// Transfer the token to the buyer
        emit Purchased(id, _msgSender()); // Emit Purchase event
    }

    /** 
    * @dev Creates a new moment and mints it to the specified account
    */
    function createMoment(
        address account, 
        string memory uri
    ) 
        external virtual 
        onlyRole(MINTER_ROLE)  
        returns (uint256 id) 
    {
        uint256 _id = ids.current(); // Get current token ID
        ids.increment(); // Increment the token counter
        _safeMint(account, _id); // Mint the new token to the account
        _setTokenURI(_id, uri); // Set metadata URI for the token
        emit Created(account, _id); // Emit created event
        return _id; // Return the newly created token ID
    }

    /** 
    * @dev Creates multiple moments and mints them to the specified account 
    */
    function createMoments(
        address account,
        uint256 numberOfMoments,
        string[] memory uri
    ) 
        external virtual 
        onlyRole(MINTER_ROLE)  
        returns (uint256[] memory _ids) 
    {
        uint256[] memory _idsArray = new uint256[](numberOfMoments); // Create array to store new token IDs

        for (uint i = 0; i < numberOfMoments; i++){
            _idsArray[i] = ids.current(); // Get current token ID
            ids.increment(); // Increment token counter for each new token         
        }
        _mintBatch(account, _idsArray, uri); // Mint batch of tokens with respective URIs

        emit CreatedBatch(account, _idsArray); // Emit batch creation event
        return _idsArray; // Return list of newly created token IDs
    }

    /** 
    * @dev Deletes a moment id the caller is the owner
    */
    function deleteMoment(uint256 id) external virtual {
        require(
            msg.sender == ownerOf(id),
            "Must be owner of Moment to delete Moment"
        );

        _burn(id); // Burn the token, removing it from circulation
        emit Deleted(id); // Emit deletion event
    }

    /** 
    * @dev CSets the sale price of a specific moment
    */
    function setPrice(uint256 id,uint price) external virtual {
        require(msg.sender == ownerOf(id)); // Ensure only the owner can set the price
        require(auction[id].status != Stages.SaleInProgress); // Ensure the sale is not already in progress

        if (price == 0) {
            auction[id].status = Stages.NotForSale; // Mark as not for sale if price is zero
            auction[id].buyer = address(0); // Clear the buyer info
        } else {
            auction[id].status = Stages.ForSale; // Mark as for sale if price is non-zero
        }
        auction[id].price = price; // Update the price

        emit AuctionPrice(id, price); // Emit price update event
    }

    /** 
    * @dev Returns the price of the moment with the given ID
    */
    function getPrice(uint256 id) external view virtual returns (uint) {
        return auction[id].price;
    }
    
    /** 
    * @dev Returns Sale status of an ID
    */
    function getSaleStatus(uint256 id) external view virtual returns (Stages) {
        return auction[id].status;
    }

    /** 
    * @dev Returns the royalty owner
    */
    function getRoyaltyOwner() external view virtual returns (address) {
        return royaltyOwner;
    }

    /** 
    * @dev Returns the royalty rate
    */
    function getRoyaltyRate() external view virtual returns (uint256) {
        return rate;
    }

    /** 
    * @dev Returns the current ID
    */
    function getCurrentId() external view virtual returns (uint256){
        return ids.current() - 1;
    }

    /** 
    * @dev Set the Royalty Owner
    */
    function setRoyaltyOwner(address payable newOwner) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOwner != address(0)); // Ensure new owner is not 0x0 address
        royaltyOwner = newOwner; // Set new owner
        emit RoyaltyOwnerSet(royaltyOwner); // Emit RoyaltyOwnerSet event
    }

    /** 
    * @dev Set Royalty Rate
    */
    function setRoyaltyRate(uint256 _rate) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        rate = _rate; // calculate royalty fee in 1 basis point --- 1 basis point = 0.01%
        emit RoyaltyRateSet(rate); // Eiit RoyaltyRateSet event
    }
    

    /**
    * @dev Set Authorized marketplace addresses
    */
    function setMarketplace(address [] calldata authorizedList) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        delete authorizedMarketplaces; // delete existing marketplace list
        for (uint i = 0; i < authorizedList.length; i++) {
            authorizedMarketplaces.push(authorizedList[i]); // Add addresses to new list
        }
        emit ModifiedMarketplace(authorizedList); // emit ModifiedMarketplace event 
    }
    
    /**
    * @dev Get Authorized marketplace addresses
    */
    function getMarketplace() external view virtual returns (address[] memory) {
        return authorizedMarketplaces;
    }

    /**
    * @dev Clear Authorized marketplace addresses
    */
    function clearMarketplace() external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        delete authorizedMarketplaces;
        emit MarketplaceListCleared();
    }

    /**
    * @dev custom _beforeTokenTransfer code
    */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) 
        internal virtual override 
    {
        if(from != address(0) && to != address(0)) {
            // check if sender is an authorized marketplace address
            for (uint i = 0; i < authorizedMarketplaces.length; i++) {
                if (authorizedMarketplaces[i] == _msgSender()) {
                    // short circuit royalty enforcement as it's handled by the marketplace
                    return;
                }
            }
            
            require(auction[id].buyer == to); // Ensure auction buyer is TO address
            require(auction[id].status == Stages.SaleInProgress); // Ensure auction status is SALEINPROGRESS

            auction[id].status = Stages.NotForSale;  // reset auction sale so NFT is no longer for sale

            auction[id].buyer = address(0); // Reset buyer
            
            uint256 price = auction[id].price; // Copy auction sale price
            auction[id].price = 0; // reset auction price
          
            uint256 fee = (price * rate) / 10000; // calculate royalty fee
            
            (bool success, ) = royaltyOwner.call{value: fee}(""); // Send royalties to Royalty Onwer
            require(success, "Royalty transfer failed");
        
            (success, ) = payable(ownerOf(id)).call{value: price - fee}("");  // transfer funds minus fee to seller
            require(success, "Seller transfer failed");
        }
    }
    
     /**
    * @dev Internal batch mint function 
    */   
    function _mintBatch(   
        address account, 
        uint256[] memory _ids, 
        string[] memory uri
    ) 
        internal virtual  
    {
        require(account != address(0)); // Ensure account address is not 0x0 address
        require(_ids.length == uri.length); // Ensure uri and Ids array lengths match

        address operator = _msgSender(); // set caller to operator

        for (uint i = 0; i < _ids.length; i++) {
               _safeMint(account, _ids[i]); // transfer moment to account address
               _setTokenURI(_ids[i], uri[i]); // set token URI for moment      
        }

        emit TransferredBatch(operator, address(0), account, _ids); // Emit TransferredBatch event
    }

    /**
    * @dev Mandatory access controlled function for authorizing upgrades 
    */
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(DEFAULT_ADMIN_ROLE) {}   
}