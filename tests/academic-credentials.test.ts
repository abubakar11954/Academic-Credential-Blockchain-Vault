import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

/**
 * Academic Credentials Smart Contract Tests
 * 
 * This test suite validates the core functionality of the academic credentials
 * registry smart contract using Clarinet SDK v3.x and Simnet.
 */

const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const institution1 = accounts.get('wallet_1')!;
const institution2 = accounts.get('wallet_2')!;

const CONTRACT_NAME = 'academic-credentials';

/**
 * Test helper to create a valid 32-byte credential hash
 */
function createCredentialHash(suffix: string = '01'): Uint8Array {
  const hex = '12'.repeat(15) + suffix;
  return Uint8Array.from(Buffer.from(hex, 'hex'));
}

describe('Academic Credentials Contract', () => {
  
  it('should initialize with correct owner and default state', () => {
    // Check contract owner
    const ownerResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-contract-owner', [], deployer);
    expect(ownerResult.result).toBe(Cl.standardPrincipal(deployer));
    
    // Check contract status
    const statusResult = simnet.callReadOnlyFn(CONTRACT_NAME, 'get-contract-status', [], deployer);
    const status = statusResult.result as any;
    expect(status.data['paused']).toBe(Cl.bool(false));
    expect(status.data['total-credentials']).toBe(Cl.uint(0));
    expect(status.data['next-institution-id']).toBe(Cl.uint(1));
  });

  it('should allow owner to add credential types', () => {
    const typeName = 'bachelor-degree';
    const description = 'Bachelor degree in various fields';
    const requirements = 'Completion of 4-year undergraduate program';

    // Add credential type
    const result = simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [
        Cl.stringAscii(typeName),
        Cl.stringAscii(description),
        Cl.stringAscii(requirements)
      ],
      deployer
    );

    expect(result.result).toBe(Cl.ok(Cl.bool(true)));

    // Verify credential type was added
    const typeInfo = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-credential-type',
      [Cl.stringAscii(typeName)],
      deployer
    );

    const typeData = typeInfo.result as any;
    expect(typeData.data['active']).toBe(Cl.bool(true));
    expect(typeData.data['description']).toBe(Cl.stringAscii(description));
  });

  it('should allow owner to add approved institutions', () => {
    const institutionName = 'Harvard University';
    const country = 'USA';
    const institutionType = 'university';

    // Add approved institution
    const result = simnet.callPublicFn(
      CONTRACT_NAME,
      'add-approved-institution',
      [
        Cl.standardPrincipal(institution1),
        Cl.stringAscii(institutionName),
        Cl.stringAscii(country),
        Cl.stringAscii(institutionType)
      ],
      deployer
    );

    expect(result.result).toBe(Cl.ok(Cl.uint(1))); // First institution gets ID 1

    // Verify institution is approved
    const isApproved = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'is-institution-approved',
      [Cl.standardPrincipal(institution1)],
      deployer
    );

    expect(isApproved.result).toBe(Cl.bool(true));
  });

  it('should allow approved institutions to issue credentials', () => {
    // Setup: Add credential type and approve institution
    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [
        Cl.stringAscii('bachelor-degree'),
        Cl.stringAscii('Bachelor degree'),
        Cl.stringAscii('4-year program')
      ],
      deployer
    );

    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-approved-institution',
      [
        Cl.standardPrincipal(institution1),
        Cl.stringAscii('Harvard University'),
        Cl.stringAscii('USA'),
        Cl.stringAscii('university')
      ],
      deployer
    );

    // Issue credential
    const credentialHash = createCredentialHash();
    const result = simnet.callPublicFn(
      CONTRACT_NAME,
      'issue-credential',
      [
        Cl.buffer(credentialHash),
        Cl.stringAscii('bachelor-degree'),
        Cl.stringAscii('student001@harvard.edu'),
        Cl.stringAscii('John Doe'),
        Cl.stringAscii('Computer Science'),
        Cl.stringAscii('2024-05-15'),
        Cl.some(Cl.stringAscii('A+'))
      ],
      institution1
    );

    expect(result.result).toBe(Cl.ok(Cl.buffer(credentialHash)));

    // Verify credential exists
    const credential = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'get-credential',
      [Cl.buffer(credentialHash)],
      deployer
    );

    const credData = credential.result as any;
    expect(credData.data['issuer']).toBe(Cl.standardPrincipal(institution1));
    expect(credData.data['student-name']).toBe(Cl.stringAscii('John Doe'));
    expect(credData.data['revoked']).toBe(Cl.bool(false));
  });

  it('should allow credential verification', () => {
    // Setup and issue credential (reusing previous setup)
    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [Cl.stringAscii('bachelor-degree'), Cl.stringAscii('Bachelor degree'), Cl.stringAscii('4-year program')],
      deployer
    );

    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-approved-institution',
      [Cl.standardPrincipal(institution1), Cl.stringAscii('Harvard University'), Cl.stringAscii('USA'), Cl.stringAscii('university')],
      deployer
    );

    const credentialHash = createCredentialHash('02');
    simnet.callPublicFn(
      CONTRACT_NAME,
      'issue-credential',
      [
        Cl.buffer(credentialHash),
        Cl.stringAscii('bachelor-degree'),
        Cl.stringAscii('student002@harvard.edu'),
        Cl.stringAscii('Jane Smith'),
        Cl.stringAscii('Mathematics'),
        Cl.stringAscii('2024-05-15'),
        Cl.none()
      ],
      institution1
    );

    // Verify credential
    const verification = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'verify-credential',
      [Cl.buffer(credentialHash)],
      deployer
    );

    const verifyData = verification.result as any;
    expect(verifyData.data['valid']).toBe(Cl.bool(true));
    expect(verifyData.data['issuer']).toBe(Cl.standardPrincipal(institution1));
    expect(verifyData.data['revoked']).toBe(Cl.bool(false));
  });

  it('should allow institutions to revoke their own credentials', () => {
    // Setup and issue credential
    const credentialHash = createCredentialHash('03');
    
    // Add credential type and institution first
    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [Cl.stringAscii('bachelor-degree'), Cl.stringAscii('Bachelor degree'), Cl.stringAscii('4-year program')],
      deployer
    );

    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-approved-institution',
      [Cl.standardPrincipal(institution1), Cl.stringAscii('Harvard University'), Cl.stringAscii('USA'), Cl.stringAscii('university')],
      deployer
    );

    // Issue credential
    simnet.callPublicFn(
      CONTRACT_NAME,
      'issue-credential',
      [
        Cl.buffer(credentialHash),
        Cl.stringAscii('bachelor-degree'),
        Cl.stringAscii('student003@harvard.edu'),
        Cl.stringAscii('Bob Johnson'),
        Cl.stringAscii('Physics'),
        Cl.stringAscii('2024-05-15'),
        Cl.none()
      ],
      institution1
    );

    // Revoke credential
    const revocationReason = 'Academic misconduct discovered';
    const revokeResult = simnet.callPublicFn(
      CONTRACT_NAME,
      'revoke-credential',
      [Cl.buffer(credentialHash), Cl.stringAscii(revocationReason)],
      institution1
    );

    expect(revokeResult.result).toBe(Cl.ok(Cl.bool(true)));

    // Verify credential is now invalid
    const verification = simnet.callReadOnlyFn(
      CONTRACT_NAME,
      'verify-credential',
      [Cl.buffer(credentialHash)],
      deployer
    );

    const verifyData = verification.result as any;
    expect(verifyData.data['valid']).toBe(Cl.bool(false));
    expect(verifyData.data['revoked']).toBe(Cl.bool(true));
  });

  it('should prevent unauthorized actions', () => {
    // Non-owner cannot add credential types
    const result1 = simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [Cl.stringAscii('fake-type'), Cl.stringAscii('Fake'), Cl.stringAscii('None')],
      institution1
    );
    expect(result1.result).toBe(Cl.error(Cl.uint(100))); // ERR-NOT-AUTHORIZED

    // Non-owner cannot add institutions
    const result2 = simnet.callPublicFn(
      CONTRACT_NAME,
      'add-approved-institution',
      [Cl.standardPrincipal(institution2), Cl.stringAscii('Fake Uni'), Cl.stringAscii('XX'), Cl.stringAscii('fake')],
      institution1
    );
    expect(result2.result).toBe(Cl.error(Cl.uint(100))); // ERR-NOT-AUTHORIZED
  });

  it('should prevent unapproved institutions from issuing credentials', () => {
    // Add credential type but don't approve institution
    simnet.callPublicFn(
      CONTRACT_NAME,
      'add-credential-type',
      [Cl.stringAscii('bachelor-degree'), Cl.stringAscii('Bachelor degree'), Cl.stringAscii('4-year program')],
      deployer
    );

    // Try to issue credential from unapproved institution
    const credentialHash = createCredentialHash('04');
    const result = simnet.callPublicFn(
      CONTRACT_NAME,
      'issue-credential',
      [
        Cl.buffer(credentialHash),
        Cl.stringAscii('bachelor-degree'),
        Cl.stringAscii('student@fake.edu'),
        Cl.stringAscii('Fake Student'),
        Cl.stringAscii('Fake Program'),
        Cl.stringAscii('2024-05-15'),
        Cl.none()
      ],
      institution2 // Not approved
    );

    expect(result.result).toBe(Cl.error(Cl.uint(104))); // ERR-INSTITUTION-NOT-APPROVED
  });

});