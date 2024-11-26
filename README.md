# charity-pool
 

# Staking and Donation Smart Contract

This project is a smart contract written in Clarity for the Stacks blockchain. It implements staking, voting, donation distribution, and leaderboard tracking functionality using fungible tokens.

## Overview

The contract allows users to:
1. Stake tokens to the contract and earn rewards.
2. Withdraw their staked tokens with a portion donated.
3. Vote for a charity to receive donations.
4. Distribute donations to the selected charity.
5. Track contributions and display a leaderboard.

## Contract Structure

### Constants and Variables
- **`contract-owner`**: The address that owns the contract.
- **`balances`**: Map to track token balances of principals.
- **`stakers`**: Map to track users' staked amounts.
- **`votes`**: Map to track users' votes for charities.
- **`leaderboard`**: Map to track total donations by charity.

### Public Functions
- **`stake(amount uint)`**: Stake a given amount of tokens to the contract.
- **`withdraw()`**: Withdraw staked tokens, with a percentage donated.
- **`set-donation-percentage(percentage uint)`**: Set the donation percentage.
- **`vote(charity principal)`**: Vote for a charity to receive donations.
- **`distribute-donations()`**: Distribute donations to the voted charity.
- **`set-charity(charity principal)`**: Set the contract's charity address.
- **`get-leaderboard(charity principal)`**: Get the leaderboard entry for a charity.

### Private Functions
- **`update-leaderboard(charity principal, amount uint)`**: Update the leaderboard with the given amount for a charity.

## Usage

### Deployment
1. Deploy the fungible token contract.
2. Deploy the staking and donation contract.

### Testing
We have included tests to validate the functionality of the contract. Below is an example of the test file:

```typescript
import { describe, it, expect } from "vitest";

describe("Staking and Donation Contract", () => {
  it("should allow users to stake tokens", async () => {
    const amount = 100;
    const result = await stakingContract.stake(amount);
    expect(result.success).toBe(true);
  });
});
```

## How It Works

1. **Staking:** Users can stake tokens, which are tracked in the `stakers` map.
2. **Withdrawals:** When withdrawing, a percentage of the staked tokens is donated, and the rest is transferred back.
3. **Voting:** Users can vote for a charity, and only one vote per user is allowed.
4. **Distributions:** Donations are distributed to the charity based on user votes and tracked in the leaderboard.

## Error Codes
- **u100**: Insufficient funds or invalid percentage.
- **u101**: Invalid stake or withdrawal request.
- **u102**: Percentage value exceeds 100%.
- **u103**: User has already voted.

## Prerequisites
- Node.js and Clarinet installed.
- Vitest for running tests.

## Installation
1. Clone the repository.
2. Install dependencies with `npm install`.
3. Run tests with `npx test`.

## License
This project is licensed under the MIT License.
