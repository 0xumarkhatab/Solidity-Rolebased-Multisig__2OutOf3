pragma solidity ^0.8.0;

contract RolebasedMultisig {
    struct Transaction {
        address[] potentialSigners;
        address[] signers;
        bytes data;
        address to;
        uint value;
        mapping(address => uint) depositors;
    }

    mapping(bytes32 => Transaction) public transactions;

    mapping(address => string) public roles;
    address admin;

    constructor() public {
        admin = msg.sender;
    }

    function proposeTransaction(bytes32 txHash, address[] memory potentialSigners, address to, uint value, bytes memory data) public {
        require(potentialSigners.length == 3, "Three potential signers are required");
        transactions[txHash] = Transaction(potentialSigners, new address[](0), data, to, value);
    }

    function setRole(address user, string memory role) public {
        require(msg.sender == admin, "Only the admin can set roles");
        if (role == "admin") {
            roles[user] = Roles.Admin;
        } else if (role == "manager") {
            roles[user] = Roles.Manager;
        }
    }

    function confirmTransaction(bytes32 txHash) public payable {
        require(msg.value > 0, "Sender must send some amount");
        require(msg.sender in transactions[txHash].potentialSigners, "Sender is not a potential signer for this transaction");
        require(!(msg.sender in transactions[txHash].signers), "Sender has already signed this transaction");
        transactions[txHash].signers.push(msg.sender);
        transactions[txHash].depositors[msg.sender] = msg.value;
        if (transactions[txHash].signers.length >= 2) {
            executeTransaction(txHash);
        }
    }

    function deposit(bytes32 txHash) public payable {
        require(transactions[txHash].potentialSigners.length > 0, "Transaction not found");
        require(transactions[txHash].depositors[msg.sender] + msg.value >= transactions[txHash].value, "Deposit amount must be equal or greater than the transaction value");
        transactions[txHash].depositors[msg.sender] += msg.value;
    }
function executeTransaction(bytes32 txHash) internal {
    // Check if enough signers have signed the transaction
    require(transactions[txHash].signers.length >= 2, "Two or more signers are required to execute the transaction");
    // Check if there is at least one admin and one manager among the signers
    bool adminFound = false;
    bool managerFound = false;
    for (uint i = 0; i < transactions[txHash].signers.length; i++) {
        if (roles[transactions[txHash].signers[i]] == "admin") {
            adminFound = true;
        } else if (roles[transactions[txHash].signers[i]] == "manager") {
            managerFound = true;
        }
        if (adminFound && managerFound) {
            break;
        }
    }
    require(adminFound && managerFound, "Transaction requires at least one admin and one manager among the signers");
    // Check if the signers have deposited enough funds for the transaction
    uint256 totalDeposit = 0;
    for (uint i = 0; i < transactions[txHash].signers.length; i++) {
        totalDeposit += deposit[transactions[txHash].signers[i]];
    }
    require(totalDeposit >= transactions[txHash].toAmount, "Signers have not deposited enough funds for the transaction");
    // Execute the transaction
    require(address(transactions[txHash].to).call.value(transactions[txHash].toAmount)(transactions[txHash].data), "Transaction execution failed");
    // Subtract the used deposit from the signers' deposits
    for (uint i = 0; i < transactions[txHash].signers.length; i++) {
        deposit[transactions[txHash].signers[i]] -= transactions[txHash].toAmount;
    }
    // Delete the transaction after execution
    delete transactions[txHash];
}

}           
