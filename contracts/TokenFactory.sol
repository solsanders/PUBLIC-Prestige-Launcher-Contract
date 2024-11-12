// Made by Prestige https://prestigenode.com https://prestigelauncher.com
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenFactory is Ownable, ReentrancyGuard {
    uint256 public contractFee = 10 * 1e18; // Contract creation fee (fee will be updated on launch)
    uint256 public revokeMintFee = 5 * 1e18; // Revoke Minting Fee (fee will be updated on launch)
    uint256 public revokePausabilityFee = 5 * 1e18; // Revoke Pausable Fee (fee will be updated on launch)
    uint256 public immutable MAX_INITIAL_SUPPLY = 1e30; // 1 Trillion Supply Limit
    uint256 public constant ARGOCHAIN_CHAIN_ID = 1299;

    event TokenCreated(
        address indexed creator,
        address tokenAddress,
        string name,
        string symbol,
        uint256 initialSupply,
        uint8 customDecimals,
        bool mintingRevoked,
        bool pausabilityRevoked
    );

    event ContractFeeUpdated(uint256 oldFee, uint256 newFee);
    event RevokeMintFeeUpdated(uint256 oldFee, uint256 newFee);
    event RevokePausabilityFeeUpdated(uint256 oldFee, uint256 newFee);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event DebugLog(string message);

    constructor() Ownable(msg.sender) {}

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 customDecimals,
        bool revokeMintAuthority,
        bool revokePausability
    ) external payable nonReentrant {
        emit DebugLog("Entered createToken");

        require(block.chainid == ARGOCHAIN_CHAIN_ID, "This function can only be called on ArgoChain");
        emit DebugLog("Passed chain ID check");

        uint256 requiredFee = contractFee;
        if (revokeMintAuthority) {
            requiredFee += revokeMintFee;
        }
        if (revokePausability) {
            requiredFee += revokePausabilityFee;
        }

        require(msg.value >= requiredFee, "Insufficient fee amount");
        emit DebugLog("Fee requirement met");

        require(initialSupply <= MAX_INITIAL_SUPPLY, "Initial supply exceeds maximum allowed");
        require(customDecimals >= 2 && customDecimals <= 18, "Decimals must be between 2 and 18");
        emit DebugLog("Initial supply and decimals validated");

        uint8 finalDecimals = customDecimals == 0 ? 18 : customDecimals;

        ERC20Token newToken = new ERC20Token(
            name,
            symbol,
            initialSupply,
            finalDecimals,
            msg.sender,
            revokePausability
        );
        emit DebugLog("Token deployed");

        if (revokeMintAuthority) {
            try newToken.revokeMintingAuthority() {
                emit DebugLog("Minting authority revoked successfully");
            } catch {
                emit DebugLog("Failed to revoke minting authority");
            }
        }

        emit TokenCreated(
            msg.sender,
            address(newToken),
            name,
            symbol,
            initialSupply,
            finalDecimals,
            revokeMintAuthority,
            revokePausability
        );
        emit DebugLog("TokenCreated event emitted");
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");
        emit FundsWithdrawn(owner(), contractBalance);
        payable(owner()).transfer(contractBalance);
    }

    function updateContractFee(uint256 newFee) external onlyOwner {
        require(newFee <= 200 * 1e18, "Fee exceeds the maximum limit");
        emit ContractFeeUpdated(contractFee, newFee);
        contractFee = newFee;
    }

    function updateRevokeMintFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100 * 1e18, "Fee exceeds the maximum limit");
        emit RevokeMintFeeUpdated(revokeMintFee, newFee);
        revokeMintFee = newFee;
    }

    function updateRevokePausabilityFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100 * 1e18, "Fee exceeds the maximum limit");
        emit RevokePausabilityFeeUpdated(revokePausabilityFee, newFee);
        revokePausabilityFee = newFee;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract ERC20Token is ERC20Pausable, Ownable {
    bool public mintingRevoked = false;
    bool public pausabilityRevoked = false;
    uint8 private _customDecimals;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint8 customDecimals,
        address tokenCreator,
        bool _revokePausability
    )
        ERC20(name, symbol)
        Ownable(tokenCreator)
    {
        _customDecimals = customDecimals;
        pausabilityRevoked = _revokePausability;
        _mint(tokenCreator, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(!mintingRevoked, "Minting authority has been revoked");
        _mint(to, amount);
    }

    function revokeMintingAuthority() external onlyOwner {
        require(!mintingRevoked, "Minting authority already revoked");
        mintingRevoked = true;
    }

    function pause() external onlyOwner {
        require(!pausabilityRevoked, "Pausability has been revoked");
        _pause();
    }

    function unpause() external onlyOwner {
        require(!pausabilityRevoked, "Pausability has been revoked");
        _unpause();
    }

    function revokePausability() external onlyOwner {
        require(!pausabilityRevoked, "Pausability already revoked");
        pausabilityRevoked = true;
    }
}
