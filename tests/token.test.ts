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
