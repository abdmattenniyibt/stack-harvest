# Stack Harvest Smart Contract

A comprehensive DeFi smart contract for the Stacks blockchain that combines staking, yield farming, NFT rewards, DAO governance, and treasury management.

## Features

- **Staking Mechanism**
  - Flexible staking periods
  - Bonus multipliers for longer lock periods
  - Secure unstaking with time-lock verification

- **Reward System**
  - Dynamic reward calculation based on stake amount and duration
  - NFT rewards for active stakers
  - Harvest tokens distribution

- **DAO Governance**
  - Proposal creation and management
  - Democratic voting system
  - Execution of approved proposals
  - Built-in safety checks

- **Treasury Management**
  - Secure fund management
  - Protected spending mechanism
  - Balance tracking

## Error Codes

- `1000`: Invalid stake amount
- `1001`: Invalid lock period
- `1002`: Empty proposal description
- `1003`: Invalid proposal ID
- `1004`: Invalid treasury spend amount
- `1005`: Invalid recipient
- `100`: Lock period not expired
- `101`: No stake found
- `200`: Reward claim error
- `300`: Proposal already executed
- `301`: Proposal not found
- `400`: Execution conditions not met
- `401`: Invalid proposal execution
- `500`: Insufficient treasury balance
- `501`: Treasury not initialized

## Functions

### Staking
```clarity
(stake (amount uint) (lock-period uint))
(unstake)
```

### Rewards
```clarity
(claim-reward)
```

### Governance
```clarity
(create-proposal (description (string-ascii 200)))
(vote-proposal (proposal-id uint) (support bool))
(execute-proposal (proposal-id uint))
```

### Treasury
```clarity
(fund-treasury (amount uint))
(spend-treasury (amount uint) (recipient principal))
```
## License

This project is licensed under the MIT License.
