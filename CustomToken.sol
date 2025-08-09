// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CustomToken (CTK)
 * @dev ERC-20 Token Implementation with additional features
 * Features: Minting, Burning, Pausable, Owner controls
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract CustomToken is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals;
    address public owner;
    bool public paused;
    
    // Additional features
    mapping(address => bool) public blacklisted;
    uint256 public maxSupply;
    uint256 public mintRate; // tokens per block for auto-minting
    uint256 public lastMintBlock;

    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event Pause();
    event Unpause();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Blacklist(address indexed account, bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Account is blacklisted");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        uint256 _maxSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        maxSupply = _maxSupply * 10**_decimals;
        
        // Mint initial supply to deployer
        uint256 initialAmount = _initialSupply * 10**_decimals;
        _totalSupply = initialAmount;
        _balances[msg.sender] = initialAmount;
        
        lastMintBlock = block.number;
        mintRate = 100 * 10**_decimals; // 100 tokens per block
        
        emit Transfer(address(0), msg.sender, initialAmount);
    }

    // Standard ERC-20 functions
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(msg.sender) 
        notBlacklisted(to) 
        returns (bool) 
    {
        require(to != address(0), "Transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner_, address spender) public view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(address spender, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(msg.sender) 
        returns (bool) 
    {
        require(spender != address(0), "Approve to zero address");
        
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        whenNotPaused 
        notBlacklisted(from) 
        notBlacklisted(to) 
        returns (bool) 
    {
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // Additional functionality
    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Mint to zero address");
        require(_totalSupply + amount <= maxSupply, "Exceeds max supply");

        _totalSupply += amount;
        _balances[to] += amount;

        emit Transfer(address(0), to, amount);
        emit Mint(to, amount);
    }

    function burn(uint256 amount) public {
        require(_balances[msg.sender] >= amount, "Insufficient balance to burn");

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        emit Transfer(msg.sender, address(0), amount);
        emit Burn(msg.sender, amount);
    }

    function pause() public onlyOwner {
        paused = true;
        emit Pause();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpause();
    }

    function setBlacklist(address account, bool status) public onlyOwner {
        blacklisted[account] = status;
        emit Blacklist(account, status);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setMintRate(uint256 _mintRate) public onlyOwner {
        mintRate = _mintRate;
    }

    // Auto-mint function (can be called by anyone)
    function autoMint() public {
        uint256 blocksPassed = block.number - lastMintBlock;
        if (blocksPassed > 0 && mintRate > 0) {
            uint256 mintAmount = blocksPassed * mintRate;
            if (_totalSupply + mintAmount <= maxSupply) {
                _totalSupply += mintAmount;
                _balances[owner] += mintAmount;
                lastMintBlock = block.number;
                emit Transfer(address(0), owner, mintAmount);
                emit Mint(owner, mintAmount);
            }
        }
    }

    // Emergency functions
    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // View functions
    function getContractInfo() public view returns (
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply,
        uint256 _maxSupply,
        address _owner,
        bool _paused
    ) {
        return (name, symbol, decimals, _totalSupply, maxSupply, owner, paused);
    }

    // Receive function to accept ETH
    receive() external payable {}
}
