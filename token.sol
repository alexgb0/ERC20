// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface ERC20x {

	/// @param _owner The address from which the balance will be retrieved
	/// @return balance the balance
	function balanceOf(address _owner) external view returns (uint256 balance);

	/// @notice send `_value` token to `_to` from `msg.sender`
	/// @param _to The address of the recipient
	/// @param _value The amount of token to be transferred
	/// @return success Whether the transfer was successful or not
	function transfer(address _to, uint256 _value)  external returns (bool success);

	/// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
	/// @param _from The address of the sender
	/// @param _to The address of the recipient
	/// @param _value The amount of token to be transferred
	/// @return success Whether the transfer was successful or not
	function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

	/// @notice `msg.sender` approves `_addr` to spend `_value` tokens
	/// @param _spender The address of the account able to transfer the tokens
	/// @param _current The current ammount in the `_spender` account
	/// @param _value The amount of wei to be approved for transfer
	/// @return success Whether the approval was successful or not
	function approve(address _spender, uint256 _current, uint256 _value) external returns (bool success);

	/// @param _owner The address of the account owning tokens
	/// @param _spender The address of the account able to transfer the tokens
	/// @return remaining Amount of remaining tokens allowed to spent
	function allowance(address _owner, address _spender) external view returns (uint256 remaining);

	event Transfer(address indexed _from, address indexed _to, uint256 _value);
	event Approval(address indexed _owner, address indexed _spender, uint256 _oldValue, uint256 _value);
}

interface Stacking {
	function stack(uint256 _ammount) external;
	function reedem(uint256 _ammount) external;
	function stack_balance(address _owner) external view returns (uint256);
}

contract Token is ERC20x, Stacking {
	mapping(address => uint256) balances;
	mapping(address => mapping(address => uint256)) transactions;

	string m_name;
	string m_symbol;
	uint8 m_decimals;
	uint256 m_supply;
    address m_owner;

    modifier only_owner {
        require(msg.sender == m_owner);
        _;
    }

	//constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _supply, address _owner) {
	constructor() {
		m_name = "TestToken";
		m_symbol = "TTK";
		m_decimals = 8;
		m_supply = 1_000_000;
        m_owner = 0x3D9942E4E74c129b1d33aBBB2C28d5CC2a754538;
	}

	function name() public view returns (string memory) { return m_name; }
	function symbol() public view returns (string memory) { return m_symbol; }
	function decimals() public view returns (uint8) { return m_decimals; }
	function totalSupply() public view returns (uint256) { return m_supply; }

	/* Stacking implementation */
	uint constant stack_const = 2;
	struct Stack {
		uint256 timestamp;
		uint256 stack_balance;
	}
	mapping(address => Stack) stacks;
	uint256 stacking_time = 5 seconds;
	function stack(uint256 _ammount) override external {
		require(_ammount > 0, "Can't stack <0");
		require(_ammount <= stacks[msg.sender].stack_balance, "Can't stack more than you have.");
		balances[msg.sender] -= _ammount; // UNDERFLOW! BECAREFUL
		stacks[msg.sender] = Stack(block.timestamp, _ammount);
	}

	function reedem(uint256 _ammount) override external {
		require(_ammount > 0, "Can't reedem <0");
		require(_ammount <= stacks[msg.sender].stack_balance, "Can't reedem more than you have.");
		require(stacks[msg.sender].stack_balance > 0, "Your stack balance must be bigger than 0");
		require(block.timestamp > stacks[msg.sender].timestamp, "You can't reedem your stack yet");

		balances[msg.sender] += _ammount * stack_const;
		stacks[msg.sender].stack_balance -= _ammount; /* UNDERFLOW! BECAREFUL */

		if (stacks[msg.sender].stack_balance == 0)
			stacks[msg.sender].timestamp = block.timestamp;
	}

	function stack_balance(address _owner) override external view returns (uint256) {
		require(_owner != address(0), "Missing argument!");
		return stacks[_owner].stack_balance;
	}
	/* ======================= */

	function balanceOf(address _owner) override external view returns (uint256 balance) {
		return balances[_owner];
	}
	
	function transfer(address _to, uint256 _value) override external returns (bool success) {
		require(_value > 0);
		require(balances[msg.sender] > 0);

		balances[msg.sender] -= _value;
		balances[_to] += _value;
		return true;
	}

	function transferFrom(address _from, address _to, uint256 _value) override external returns (bool success) {
		require(_value > 0);
		require(balances[_from] > 0);

		transactions[_from][_to] = _value;

		emit Transfer(_from, _to, _value);
		return true;
	}

	function approve(address _spender, uint256 _current, uint256 _value) override external returns (bool success) {
		require(transactions[msg.sender][_spender] >= _value);
		require(balances[msg.sender] == _current);

		if (transactions[msg.sender][_spender] == 0) 
			delete transactions[msg.sender][_spender];
		else
			transactions[msg.sender][_spender] -= _value;

		uint old = balances[msg.sender];
		balances[msg.sender] -= _value;
		balances[_spender] += _value;
		
		emit Approval(msg.sender, _spender, old, _value);
		return true;
	}

	function allowance(address _owner, address _spender) override external view returns (uint256 remaining) {
		return transactions[_owner][_spender];
	}

    function _airdrop(address _to, uint256 _value) public only_owner {
        require(_value > 0);
        balances[_to] = _value;
        
        emit Transfer(address(0), _to, _value);
    }
}
