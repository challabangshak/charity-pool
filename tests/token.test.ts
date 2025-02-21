import { describe, it, expect, beforeEach } from 'vitest';

// Mock state to simulate blockchain storage
let balances = new Map();
let contractOwner: string;
let user1: string;
let user2: string;

// Helper function to reset state before each test
beforeEach(() => {
  contractOwner = 'SP3T2KQ9W0E2AW8CWN6MY3M8DP93RXBB6MN0DWXVR';
  user1 = 'SP1BXH6GKH4MQX4PFPH2GKXF3WQ6DTF3CB11RZD3M';
  user2 = 'SP2X3X4NNGNDDBRBRWJB6NNFB7NMYWX86QRBP5Q3N';
  balances = new Map(); // Reset balances before each test
});

// Mock mint function
function mint(recipient: any, amount: number, sender: any) {
  if (sender !== contractOwner) {
    return { success: false, error: 'u403' }; // Only owner can mint
  }
  const currentBalance = balances.get(recipient) || 0;
  balances.set(recipient, currentBalance + amount);
  return { success: true };
}

// Mock transfer function
function transfer(sender: any, recipient: any, amount: number) {
  const senderBalance = balances.get(sender) || 0;
  if (sender === recipient) {
    return { success: false, error: 'u101' }; // Cannot transfer to self
  }
  if (senderBalance < amount) {
    return { success: false, error: 'u100' }; // Insufficient balance
  }
  balances.set(sender, senderBalance - amount);
  const recipientBalance = balances.get(recipient) || 0;
  balances.set(recipient, recipientBalance + amount);
  return { success: true };
}

// Mock get-balance function
function getBalance(owner: any) {
  return balances.get(owner) || 0;
}

// Unit tests
describe('Token Contract', () => {
  it('should mint tokens to a recipient', () => {
    const result = mint(user1, 1000, contractOwner);
    expect(result.success).toBe(true);
    expect(getBalance(user1)).toBe(1000);
  });

  it('should prevent minting tokens by non-owner', () => {
    const result = mint(user1, 1000, user1); // Non-owner trying to mint
    expect(result.success).toBe(false);
    expect(result.error).toBe('u403');
  });

  it('should transfer tokens between users', () => {
    mint(user1, 500, contractOwner); // Mint tokens to user1 first
    const result = transfer(user1, user2, 200);
    expect(result.success).toBe(true);
    expect(getBalance(user1)).toBe(300);
    expect(getBalance(user2)).toBe(200);
  });

  it('should prevent transfer when balance is insufficient', () => {
    const result = transfer(user1, user2, 100); // user1 has no tokens yet
    expect(result.success).toBe(false);
    expect(result.error).toBe('u100');
  });

  it('should prevent transferring to the same sender', () => {
    mint(user1, 500, contractOwner); // Mint tokens to user1
    const result = transfer(user1, user1, 200); // Transfer to self
    expect(result.success).toBe(false);
    expect(result.error).toBe('u101');
  });

  it('should return correct balance of a user', () => {
    mint(user1, 300, contractOwner); // Mint tokens to user1
    const balance = getBalance(user1);
    expect(balance).toBe(300);
  });
});


describe('Staking Multipliers', () => {
  let stakingMultipliers: Record<number, number>;
  let contractOwner: string;

  beforeEach(() => {
    stakingMultipliers = {};
    contractOwner = 'contract_owner';
  });

  const setDurationMultiplier = (duration: number, multiplier: number, sender: string) => {
    if (sender !== contractOwner) throw new Error('ERR_UNAUTHORIZED');
    stakingMultipliers[duration] = multiplier;
    return true;
  };

  it('should allow the contract owner to set a multiplier', () => {
    const result = setDurationMultiplier(100, 2, 'contract_owner');
    expect(result).toBe(true);
    expect(stakingMultipliers[100]).toBe(2);
  });

  it('should reject unauthorized users from setting a multiplier', () => {
    expect(() => setDurationMultiplier(100, 2, 'unauthorized_user')).toThrow('ERR_UNAUTHORIZED');
  });
});



describe('Charity Categories', () => {
  let charityCategories: Record<string, string>;
  let contractOwner: string;

  beforeEach(() => {
    charityCategories = {};
    contractOwner = 'contract_owner';
  });

  const setCharityCategory = (charity: string, category: string, sender: string) => {
    if (sender !== contractOwner) throw new Error('ERR_UNAUTHORIZED');
    charityCategories[charity] = category;
    return true;
  };

  it('should allow the contract owner to set a charity category', () => {
    const result = setCharityCategory('charity1', 'education', 'contract_owner');
    expect(result).toBe(true);
    expect(charityCategories['charity1']).toBe('education');
  });

  it('should reject unauthorized users from setting a charity category', () => {
    expect(() => setCharityCategory('charity1', 'healthcare', 'unauthorized_user')).toThrow('ERR_UNAUTHORIZED');
  });
});



describe('Referrals', () => {
  let referrals: Record<string, { totalReferred: number; bonusEarned: number }>;
  let userBalances: Record<string, number>;

  beforeEach(() => {
    referrals = {};
    userBalances = {};
  });

  const stakeWithReferral = (amount: number, referrer: string, sender: string) => {
    if (amount <= 0) throw new Error('ERR_INVALID_AMOUNT');

    userBalances[sender] = (userBalances[sender] || 0) + amount;

    if (referrals[referrer]) {
      referrals[referrer].totalReferred += 1;
      referrals[referrer].bonusEarned += Math.floor(amount * 0.1); // 10% bonus
    } else {
      referrals[referrer] = { totalReferred: 1, bonusEarned: Math.floor(amount * 0.1) };
    }

    return true;
  };

  it('should allow users to stake with a valid referral', () => {
    const result = stakeWithReferral(100, 'referrer1', 'user1');
    expect(result).toBe(true);
    expect(referrals['referrer1']).toMatchObject({ totalReferred: 1, bonusEarned: 10 });
  });

  it('should accumulate referral bonuses and counts', () => {
    stakeWithReferral(100, 'referrer1', 'user1');
    stakeWithReferral(200, 'referrer1', 'user2');
    expect(referrals['referrer1']).toMatchObject({ totalReferred: 2, bonusEarned: 30 });
  });

  it('should reject staking with zero or negative amounts', () => {
    expect(() => stakeWithReferral(0, 'referrer1', 'user1')).toThrow('ERR_INVALID_AMOUNT');
    expect(() => stakeWithReferral(-50, 'referrer1', 'user1')).toThrow('ERR_INVALID_AMOUNT');
  });
});

