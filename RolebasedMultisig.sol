//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

/* Goal of the Smart contract */

/*
This smart contract implements a role-based multi-sig wallet,
where transactions can be proposed and executed only after two or more signers,
including at least one admin and one manager, confirm the transaction.

The contract contains functions for setting up the initial roles of "admin" and "manager",
adding potential signers to a transaction, confirming a transaction, depositing funds,
executing a transaction and updating roles.

The "setRole" function allows the current admin to set the role of a user as "admin" or "manager".

The "updateRole" function allows the admin to update the role of a user.

The "proposeTransaction" function allows adding potential signers to a transaction.

The "confirmTransaction" function allows signers to confirm a transaction and deposit funds.

The "deposit" function allows depositing funds into a transaction.

The "executeTransaction" function executes the transaction if it has received two or more confirmations from signers, including at least one admin and one manager, and the funds deposited are enough to cover the transaction value.

*/

contract RolebasedMultisig {
    /* Role based Access*/
    mapping(address => bool) public admins;
    mapping(address => bool) public managers;

    /* Transaction Handling */
    mapping(bytes32 => Transaction) public transactions;
    struct Transaction {
        address[] potentialSigners;
        address[] signers;
        bytes data;
        address to;
        uint256 value;
        uint256 depositedAmount;
    }
    //Contract Owner
    address owner; // we can use special priviliges by the platform - Features to be added for it

    //Contract Constructor
    constructor() public {
        owner = msg.sender;
    }

    // Contract Events
    event Executed(bytes32 txHash);
    event RoleUpdated(address user, bytes32 newRole);

    // Function to propose a transaction
    function proposeTransaction(
        bytes32 txHash,
        address[] memory potentialSigners,
        address to,
        uint256 value,
        bytes memory data
    ) public {
        // Check if there are three potential signers
        require(
            potentialSigners.length == 3,
            "Three potential signers are required"
        );
        // Store the transaction details in the mapping
        transactions[txHash] = Transaction(
            potentialSigners,
            new address[](0),
            data,
            to,
            value,
            0
        );
    }

    // Function to set a role for a user
    function setRole(address user, bytes32 role) public {
        // Check if the caller is an admin
        require(admins[msg.sender], "Only the admin can set roles");
        // Update the role of the user
        if (role == "admin") {
            admins[msg.sender] = true;
        } else if (role == "manager") {
            managers[msg.sender] = true;
        }
    }

    // Internal function to check if an address exists in an array
    function addressExists(address[] memory _arr, address _address)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < _arr.length; i++) {
            if (_arr[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function confirmTransaction(bytes32 txHash) public payable {
        require(msg.value > 0, "Sender must send some amount");
        // Someone can confirm the transaction only if they are one of the potential signers
        require(
            addressExists(transactions[txHash].potentialSigners, msg.sender),
            "Sender is not a potential signer for this transaction"
        );
        // The transaction should not be repeatedly signed by same person
        require(
            !addressExists(transactions[txHash].signers, msg.sender),
            "Sender has already signed this transaction"
        );
        // Add caller tp the signer of the transaction
        transactions[txHash].signers.push(msg.sender);
        // Update the transaction amount that is depostited
        transactions[txHash].depositedAmount += msg.value;
        // if we have 2 out of 3 signers , we can execute the transaction
        if (transactions[txHash].signers.length >= 2) {
            executeTransaction(txHash);
        }
    }

    // deposit funds to the contract so that it can transfer the needed amount in the transaction having transaction hash as txHash

    function deposit(bytes32 txHash) public payable {
        // Depositor must be a potential Signer
        require(
            transactions[txHash].potentialSigners.length > 0,
            "Transaction not found"
        );
        // Any amount other than zero
        require(
            msg.value >= 0,
            "Deposit amount must be equal or greater than the transaction value"
        );
        transactions[txHash].depositedAmount += msg.value;
    }

    function executeTransaction(bytes32 txHash) internal {
        // Check if enough signers have signed the transaction
        require(
            transactions[txHash].signers.length >= 2,
            "Two or more signers are required to execute the transaction"
        );
        // Check if there is at least one admin and one manager among the signers
        bool adminFound = false;
        bool managerFound = false;

        for (uint256 i = 0; i < transactions[txHash].signers.length; i++) {
            if (admins[transactions[txHash].signers[i]]) {
                adminFound = true;
            } else if (managers[transactions[txHash].signers[i]]) {
                managerFound = true;
            }
            if (adminFound && managerFound) {
                break;
            }
        }
        require(
            adminFound && managerFound,
            "Transaction requires at least one admin and one manager among the signers"
        );
        // Check if the signers have deposited enough funds for the transaction
        uint256 fundsDeposited = transactions[txHash].depositedAmount;

        require(
            transactions[txHash].value <= fundsDeposited,
            "Signers do not have enough funds to execute the transaction"
        );

        // Execute the transaction
        bytes memory data = transactions[txHash].data;
        address destination = transactions[txHash].to;
        (bool success, ) = destination.call(data);
        require(success, "Transaction execution failed");

        emit Executed(txHash);
    }

    function updateRole(address user, bytes32 newRole) public {
        require(admins[msg.sender], "Only admin can update Role");
        if (newRole == "admin") {
            admins[user] = true;
        } else if (newRole == "manager") {
            managers[user] = true;
        } else {
            require(false, "Invalid Role");
        }

        emit RoleUpdated(user, newRole);
    }
}
