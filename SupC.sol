// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

pragma experimental ABIEncoderV2;  
import "@openzeppelin/contracts/access/AccessControl.sol";


contract SupC is AccessControl{

    //Constructor
    constructor() {
        // Setup permissions for the contract
        _owner = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);         //Sets up the Default Admin role and grants it to the deployer
        _setRoleAdmin(OWNR_ROLE, DEFAULT_ADMIN_ROLE);       //Sets the role granted to the deployer as the admin role
        _grantRole(OWNR_ROLE, msg.sender);                  //Grants this new role to the deployer
    }

    //Define Events
        event RawSupplierAdded(address indexed account);
        event RawSupplierRemoved(address indexed account);
        event MidSupplierAdded(address indexed account);
        event MidSupplierRemoved(address indexed account);
        event FactoryAdded(address indexed account);
        event FactoryRemoved(address indexed account);
        event ShippingFailure(string _message, uint _timeStamp);
        event ShippingSuccess(string _message, uint _trackingNo, uint _timeStamp, address _sender);

    //Define Roles
        bytes32 public constant OWNR_ROLE = keccak256("OWNER ROLE");
        bytes32 public constant RAW_ROLE = keccak256("RAW SUPPLIER ROLE");
        bytes32 public constant MID_ROLE = keccak256("MID SUPPLIER ROLE");
        bytes32 public constant FAC_ROLE = keccak256("FACTORY ROLE");

    //Define Structs and Local Variables
        uint8 private _sku_count;
        address _owner;

        //ItemModular
        struct itemModular {
            uint     sku;                   // SKU is item ID
            uint     upc;                   // UPC is item type, ex 2 = rubber, 3 = wood
            uint     originProduceDate;     // Date item produced in factory
            string   itemName;              // English description of part
            uint     productPrice;          // Product Price
            address  manufacID;             // Ethereum address of the Distributor
            /*TODO Mapping to what its made of? An array?
                Method 1) Array of Sku's that correspond to the items it was made from?
                Method 2) Array of UPC's that correspond to the items it was made from?
            */

        }
        //ItemAtomic
        struct itemAtomic {
            uint     sku;                    // SKU is item ID
            uint     upc;                    // UPC is item type, ex 2 = rubber, 3 = wood
            uint     originProduceDate;      // Date item produced in factory
            string   itemName;               // English description of part
            uint     productPrice;           // Product Price
            address  manufacID;              // Ethereum address of the Distributor
        }
        //Shipments
        struct shipment {
            uint upc;                        // Item(s) identifier
            uint quantity;                   // Number of items in the shipment
            uint timeStamp;                  // Will be used to define when shipment is sent
            address payable sender;          // ETH Address of the sender
            uint contractLeadTime;          // Predetermined allowable timeframe for delivery
        }
        //Stakeholder
        struct stakeholder {
        address   _id;                    // ETH address of the stakeholder
        string    _name;                  // name of this stakeholder
        string    _location;              // location 
        uint8     _upc;                   // what does this manufacturer make?
    }

    //Define Mappings
    mapping (uint => itemModular)       public _products;           // SKU -> Product, ID to Product
    mapping (uint => itemAtomic)        public _rawMaterials;       // SKU -> RawMaterials
    mapping (address => stakeholder)    public _stakeholders;       // List of stakeholders
    mapping (address => bytes32)        public _parties;            // Stores ranks for involved parties
    mapping (uint => shipment)          public _shipments;         // tracking No. -> shipment
    mapping (address => uint256)        public _accounts;          // list of accounts 

    //Define Modifiers
        //Used to control authority
    modifier onlyRaw() {
        require(hasRole(RAW_ROLE, msg.sender));
        _;
    }
    modifier onlyMid() {
        require(hasRole(MID_ROLE, msg.sender));
        _;
    }
    modifier onlyFac() {
        require(hasRole(FAC_ROLE, msg.sender));
        _;
    }
    modifier onlyOwner() {
        require(hasRole(OWNR_ROLE, msg.sender));
        _;
    }
    modifier onlyStakeholder() {
        require(hasRole(FAC_ROLE, msg.sender) || hasRole(MID_ROLE, msg.sender) || hasRole(RAW_ROLE, msg.sender) || hasRole(OWNR_ROLE, msg.sender));
        _;
    }

    //Functions:
    //Add a role/Remove a role – modular
    function addStakeholder(address addy, string calldata name, string calldata loc, uint8 upc, string calldata roleStr) public onlyOwner {
        // Link manufacturer credentials using the mappings/structs created above
        stakeholder memory x = stakeholder(addy, name, loc, upc);   // Create a new instance of the struct 
        _stakeholders[addy] = x;                                    // Add this to the list of stakeholders
        
        bytes32 role = keccak256(abi.encodePacked(roleStr));
        if(role == RAW_ROLE) {
            emit RawSupplierAdded(addy);
            _parties[addy] = RAW_ROLE;
            _grantRole(RAW_ROLE, addy);
        }
        if(role == MID_ROLE) {
            emit MidSupplierAdded(addy);
            _parties[addy] = MID_ROLE;
            _grantRole(MID_ROLE, addy);
        }
        if(role == FAC_ROLE) {
            emit FactoryAdded(addy);
            _parties[addy] = FAC_ROLE;
            _grantRole(FAC_ROLE, addy);
        }
    }

    function removeStakeholder(address x, string calldata roleStr) public onlyOwner {
        bytes32 ROLE = keccak256(abi.encodePacked(roleStr));
        if(hasRole(ROLE,x)) {
            _revokeRole(ROLE, x);
        }
        delete _stakeholders[x];
        delete _parties[x];
    }

    function checkStakeholder(address s) public view returns (stakeholder memory) {
        // This function will let any user to pull out stakeholder details using their address
        return _stakeholders[s];
    }
    
    //Get Price, Make Product
    function getPrice(
        uint sku
        ) public view returns (uint price) {
        // Fetch the price of a product given a SKU
        return _products[sku].productPrice;
    }

    function addProduct(
        uint originProduceDate,
        uint productPrice,
        uint upc,
        string calldata name
        ) public onlyStakeholder returns (bool suceess) {
        
        uint sku = _sku_count;
        if (_products[sku].manufacID == address(0x0) && (sku != 0)) { 
            //Checking that a product with the corresponding sku has not been made by another stakeholder
            _products[sku].sku = sku;
            _products[sku].upc = upc;
            _products[sku].originProduceDate = originProduceDate;
            _products[sku].productPrice = productPrice;
            _products[sku].itemName = name;
            _sku_count++;
            return true;
        }
        else {
            return false;
        }
    }
    
    //Function to send and receive shipments
    function sendShipment(
        uint trackingNo, 
        uint upc, 
        uint quantity, 
        uint leadTime
        ) public payable onlyStakeholder returns (bool success){
        // Function for manufacturer to send a shipment of _quanity number of _upc
        // Fill out shipment struct for a given tracking number
        _shipments[trackingNo].upc       = upc;
        _shipments[trackingNo].sender    = payable(msg.sender);
        _shipments[trackingNo].quantity  = quantity;
        _shipments[trackingNo].timeStamp = block.timestamp;
        _shipments[trackingNo].contractLeadTime = leadTime;
        // emit successful event
        emit ShippingSuccess("Items Shipped", trackingNo, block.timestamp, msg.sender);
        return true;
        
    }

    function receiveShipment(
        uint trackingNo, 
        uint upc, 
        uint quantity
        ) public payable onlyStakeholder returns (bool success) {
        /*
            Checking for the following conditions
                - Item [Tracking Number] and Quantity match the details from the sender
                - Once the above conditions are met, check if the location, shipping time and lead time (delay between when an order is placed and processed)
                 match and call the sendFunds function
                - The above conditions can be applied as nested if statements and have events triggered within as each condition is met
        */        //checking that the item and quantity received match the item and quantity shipped
        if(_shipments[trackingNo].upc == upc && _shipments[trackingNo].quantity == quantity) {
            emit ShippingSuccess("Items received", trackingNo, block.timestamp, msg.sender);            
            if (block.timestamp <= _shipments[trackingNo].timeStamp + _shipments[trackingNo].contractLeadTime) {
                //checks have been passed, send tokens from the assmbler to the manufacturer     
                //uint price = s.getPrice(upc);           
                //uint transferAmt = quantity * price;
                //sendFunds(_shipments[trackingNo].sender, transferAmt);
            } else {
                emit ShippingFailure("Payment not triggered as time criteria weas not met", block.timestamp);
            }
            return true;
        }
        else {
            emit ShippingFailure("Issue in item/quantity", block.timestamp);
            return false;
        }
    }

    function findShipment(uint8 trackingNo) public view returns (shipment memory){
        return _shipments[trackingNo];
    }

    //Functions with modifiers to produce and ship/receive modular parts

}