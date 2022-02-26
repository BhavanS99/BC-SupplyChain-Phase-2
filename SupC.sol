// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;  
import "@openzeppelin/contracts/access/AccessControl.sol";
/*###############################################################
###                                                           ###
###                       QMIND 2021                          ###
###               BC-SUPPLYCHAIN : ETHEREUM                   ###
###               CONTRACT       : STAKEHOLDER                ###
###                                                           ###
###   This contract develops a database of transactions       ###
###   - Create parts to assemble cars, track their origin     ###
###   ====================================================    ###
###   Authors: Bhavan Suthakaran                              ###
###            Max Kang                                       ###
###            Mit Patel                                      ###
###            Mitchell Sabbadini                             ###
###            Andrew Sutcliffe                               ###
###                                                           ###
##############################################################**/

contract Chain is AccessControl{

    //Define Roles
    bytes32 public constant OWNR_ROLE = keccak256("OWNER ROLE");
    bytes32 public constant FAC_ROLE = keccak256("FACTORY ROLE");
    bytes32 public constant RAW_ROLE = keccak256("RAW SUPPLIER ROLE");
    bytes32 public constant MID_ROLE = keccak256("MID SUPPLIER ROLE");

    //Constructor
    constructor() {
        // Setup permissions for the contract
        _owner = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);         // Sets up the Default Admin role and grants it to the deployer
        _setRoleAdmin(OWNR_ROLE, DEFAULT_ADMIN_ROLE);       // Sets the role granted to the deployer as the admin role
        _grantRole(OWNR_ROLE, msg.sender);                  // Grants this new role to the deployer

        // assign costs to modular parts
        _costs[4][1] = 3;
        _costs[5][1] = 2;
        _costs[6][2] = 2;
        _costs[6][1] = 1;
        _costs[7][3] = 4;
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

    //Define Structs and Local Variables
    uint8 private _sku_count = 0;
    address public _owner;

    //ItemModular
    struct itemModular {
        uint     sku;                    // SKU is item ID
        uint     upc;                    // UPC is item type, ex 2 = rubber, 3 = wood
        uint     originProduceDate;      // Date item produced in factory
        string   itemName;               // English description of part
        uint     productPrice;           // Product Price
        address  manufacID;              // Ethereum address of the Distributor
        itemAtomic[] atomComponents;     // Hold atomic components of a part
        itemModular[] modComponents;     // Hold modular components of a part
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
        uint contractLeadTime;           // Predetermined allowable timeframe for delivery
    }
    //Stakeholder
    struct stakeholder {
        address   _id;                    // ETH address of the stakeholder
        string    _name;                  // name of this stakeholder
        string    _location;              // location 
        uint8     _upc;                   // what does this manufacturer make?
    }

    //Define Mappings
    mapping (uint => shipment)                   public _shipments;          // tracking No. -> shipment
    mapping (address => bytes32)                 public _parties;            // Stores ranks for involved parties
    mapping (address => uint256)                 public _accounts;           // list of accounts 
    mapping (address => stakeholder)             public _stakeholders;       // List of stakeholders
    mapping (uint => itemModular)                public _products;            // list of completed products
    mapping(uint => mapping(uint => uint))       public _costs;              // keep track of costs of modular parts

    // Hold completed parts and resources
    itemModular[] public modularQ; 
    itemAtomic[]  public rubberQ; 
    itemAtomic[]  public metalQ;
    itemAtomic[]  public plasticQ;

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
        require(
            hasRole(FAC_ROLE, msg.sender) || 
            hasRole(MID_ROLE, msg.sender) || 
            hasRole(RAW_ROLE, msg.sender) || 
            hasRole(OWNR_ROLE, msg.sender)
            );
        _;
    }

    //Functions:
    //Add a role/Remove a role – modular
    function addStakeholder(
        address addy, 
        uint8 upc, 
        string calldata name, 
        string calldata loc, 
        string calldata roleStr
        ) public onlyOwner {
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
        // what is happening here?
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
    
    //Function to send and receive shipments
    function sendShipment(
        uint trackingNo, 
        uint upc, 
        uint quantity, 
        uint leadTime
        ) public payable onlyStakeholder returns (bool success) {
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
    function produceModularPart(
        string calldata name, 
        uint productCode,
        uint price
        ) public onlyMid {

         // We will define 3 types of modular products
        /**
        1) Chassis - cost = 3 metal               : UPC 4

        2) Motor && drivetrain - cost 2 metal     : UPC 5
        
        3) Interior - cost 2 plastic, 1 metal     : UPC 6

        4) Wheels - cost 4 rubber                 : UPC 7

        */
        require(productCode <= 7 && productCode >= 4);
        itemAtomic[] memory temp = new itemAtomic[](4);

        if (productCode != 6) {
            if (productCode == 4) {
                // Chassis
                require(metalQ.length >=  _costs[4][1]);
                for (uint i = 0; i < _costs[4][1]; i++ ) {
                    itemAtomic memory x = metalQ[metalQ.length -1];
                    temp[i] = x;
                    metalQ.pop();
                }
            }
            else if (productCode == 5) {
                // Motor and Transmission
                require(metalQ.length >=  _costs[5][1]);
                for (uint i = 0; i< _costs[5][1]; i++ ) {
                    itemAtomic memory x = metalQ[metalQ.length -1];
                    temp[i] = x;
                    metalQ.pop();
                }
            }
            else {
                // WHeels
                require(rubberQ.length >= _costs[7][3]);
                for (uint i = 0; i <_costs[7][3]; i++ ) {
                    itemAtomic memory x = rubberQ[rubberQ.length -1];
                    temp[i] = x;
                    rubberQ.pop();
                }
            }
        } else {
            // Interior
            require(metalQ.length >= _costs[6][1]);
            require(plasticQ.length >= _costs[6][2]);
            for (uint i = 0; i<_costs[6][1]; i++ ) {
                    itemAtomic memory x = metalQ[metalQ.length -1];
                    temp[i] = x;
                    metalQ.pop();
                }
            for (uint i = 0; i<_costs[6][2]; i++ ) {
                    itemAtomic memory x = plasticQ[plasticQ.length -1];
                    temp[i] = x;
                    plasticQ.pop();
                }
        }

        itemModular memory n = itemModular({
                    sku: _sku_count,
                    upc: productCode,
                    originProduceDate: block.timestamp,
                    itemName: name,
                    productPrice: price,
                    manufacID: msg.sender,
                    atomComponents: temp,
                    modComponents: itemModular[](0)
        });
        _sku_count++;

    }

    // Create an atomic part
    function produceAtomicPart(
        string calldata name, 
        uint productCode,
        uint price,
        uint quantity
        ) public onlyRaw {

        // product code is item type:
        //      1 - metal
        //      2 - plastic
        //      3 - rubber

        for (uint i = 0; i < quantity; i++ ) {
            // push quantity times to array
            itemAtomic memory n = itemAtomic({
                sku: _sku_count,
                upc: productCode,
                originProduceDate: block.timestamp,
                itemName: name,
                productPrice: price,
                manufacID: msg.sender
            });

            /**
            check type of productCode, put into appropriate array */
            // atomicQ.push(n);
            _sku_count++;
        }
    }
}
