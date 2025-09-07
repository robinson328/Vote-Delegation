# Governance Token Smart Contract

A comprehensive fungible token contract built for the Stacks blockchain with advanced governance features including voting delegation, historical vote tracking, and checkpoint systems.

## Features

### Core Token Functionality
- **ERC-20 Compatible**: Standard fungible token with transfer, approve, and allowance functionality
- **Mintable**: Contract owner can mint new tokens to any address
- **Burnable**: Token holders can burn their own tokens
- **Pausable**: Contract owner can pause/unpause all operations for emergency situations

### Governance Features
- **Vote Delegation**: Token holders can delegate their voting power to other addresses
- **Checkpoint System**: Historical voting power tracking at specific block heights
- **Vote Tracking**: Real-time tracking of delegated voting power for each address
- **Historical Queries**: Ability to query voting power at previous block heights

### Security Features
- **Input Validation**: Comprehensive validation for all parameters
- **Overflow Protection**: Safe arithmetic operations
- **Access Control**: Owner-only functions for administrative operations
- **Emergency Controls**: Pause functionality and emergency withdrawal

## Contract Structure

### Constants
- `CONTRACT_OWNER`: The deployer of the contract with administrative privileges
- Error codes ranging from `u100` to `u999` for different failure scenarios

### Data Variables
- `token-name`: The human-readable name of the token
- `token-symbol`: The ticker symbol (max 10 characters)
- `token-decimals`: Number of decimal places (0-18)
- `token-uri`: Optional metadata URI
- `paused`: Emergency pause state

### Data Maps
- `delegates`: Tracks delegation relationships (delegator -> delegatee)
- `delegate-count`: Current voting power for each delegate
- `checkpoints`: Historical voting power snapshots
- `num-checkpoints`: Number of checkpoints per account
- `allowances`: Spending allowances between accounts

## Functions

### Read-Only Functions

#### Token Information
```clarity
(get-name) -> (response string-ascii err)
(get-symbol) -> (response string-ascii err)
(get-decimals) -> (response uint err)
(get-total-supply) -> (response uint err)
(get-token-uri) -> (response (optional string-utf8) err)
```

#### Balance and Allowance
```clarity
(get-balance account) -> (response uint err)
(get-allowance owner spender) -> (response uint err)
```

#### Governance Queries
```clarity
(get-delegate account) -> (response principal err)
(get-current-votes account) -> (response uint err)
(get-prior-votes account block-height) -> (response uint err)
(get-checkpoint account checkpoint-index) -> (response (optional checkpoint-data) err)
(get-num-checkpoints account) -> (response uint err)
(has-delegated account) -> (response bool err)
```

#### Contract State
```clarity
(is-paused) -> (response bool err)
(get-account-info account) -> (response account-info err)
(get-contract-info) -> (response contract-info err)
```

### Public Functions

#### Administrative Functions
```clarity
(initialize initial-supply name symbol decimals uri) -> (response bool err)
(pause) -> (response bool err)
(unpause) -> (response bool err)
(set-token-uri new-uri) -> (response bool err)
(emergency-withdraw amount recipient) -> (response bool err)
```

#### Token Operations
```clarity
(transfer amount sender recipient memo) -> (response bool err)
(transfer-from sender recipient amount memo) -> (response bool err)
(approve spender amount) -> (response bool err)
(mint recipient amount) -> (response bool err)
(burn amount) -> (response bool err)
```

#### Governance Operations
```clarity
(delegate delegatee) -> (response bool err)
```

## Usage Examples

### Deploying the Contract
```clarity
;; Deploy and initialize with 1,000,000 tokens (6 decimals)
(contract-call? .governance-token initialize 
  u1000000000000 
  "Governance Token" 
  "GOV" 
  u6 
  (some u"https://example.com/metadata.json"))
```

### Basic Token Operations
```clarity
;; Transfer 100 tokens
(contract-call? .governance-token transfer u100000000 tx-sender 'SP1234... none)

;; Approve spending
(contract-call? .governance-token approve 'SP1234... u50000000)

;; Burn 10 tokens
(contract-call? .governance-token burn u10000000)
```

### Delegation and Governance
```clarity
;; Delegate voting power to another address
(contract-call? .governance-token delegate 'SP5678...)

;; Check current voting power
(contract-call? .governance-token get-current-votes 'SP5678...)

;; Check historical voting power
(contract-call? .governance-token get-prior-votes 'SP5678... u1000)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller lacks required permissions |
| u101 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| u102 | ERR_INVALID_AMOUNT | Invalid amount (zero or too large) |
| u103 | ERR_ALREADY_DELEGATED | Already delegated to this address |
| u104 | ERR_SELF_DELEGATION | Cannot delegate to self |
| u105 | ERR_INVALID_RECIPIENT | Invalid recipient address |
| u106 | ERR_INVALID_SPENDER | Invalid spender address |
| u107 | ERR_INSUFFICIENT_ALLOWANCE | Insufficient spending allowance |
| u108 | ERR_INVALID_BLOCK | Invalid block height |
| u109 | ERR_INVALID_INPUT | Invalid input parameter |
| u999 | ERR_PAUSED | Contract is paused |

## Security Considerations

### Access Control
- Only the contract owner can perform administrative functions
- Emergency withdrawal only works when contract is paused
- Input validation prevents common attack vectors

### Delegation Safety
- Users cannot delegate to themselves
- Delegation changes are tracked with checkpoints
- Historical voting power is immutable once recorded

### Emergency Procedures
- Contract can be paused to stop all operations
- Emergency withdrawal allows owner to recover funds when paused
- Unpause function restores normal operations

## Integration Guidelines

### For DApps
1. Use `get-current-votes` to check real-time voting power
2. Use `get-prior-votes` for historical governance decisions
3. Monitor delegation events for UI updates
4. Handle pause state in your application logic

### For Governance Systems
1. Query voting power at proposal creation block
2. Use checkpoint system for transparent vote counting
3. Implement delegation-aware voting interfaces
4. Consider delegation changes in governance timing

## Best Practices

### Token Holders
- Delegate voting power to active governance participants
- Monitor your delegate's voting behavior
- Consider the impact of transfers on voting power
- Keep track of checkpoint history for transparency