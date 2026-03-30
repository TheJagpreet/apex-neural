---
name: nodejs-testing
description: "Provides Node.js and TypeScript backend testing patterns, frameworks, and best practices. Use when writing or running tests for Node.js/TypeScript projects."
---

# Node.js Testing Skill

When testing Node.js or TypeScript backends, follow this structured approach to discover, write, and run tests.

## Framework Detection

Detect the test framework by checking these files in order:

| File | Framework |
|------|-----------|
| `vitest.config.*` / `vite.config.*` with test section | Vitest |
| `jest.config.*` / `"jest"` in `package.json` | Jest |
| `"type": "module"` + `"test"` script using `node --test` | Node.js built-in test runner |
| `.mocharc.*` / `"mocha"` in `package.json` | Mocha |
| `ava.config.*` / `"ava"` in `package.json` | AVA |
| `tap.config.*` / `"tap"` in `package.json` | Tap |

Always check `package.json` scripts and devDependencies first:
```bash
cat package.json | grep -E '"test"|"jest"|"vitest"|"mocha"|"ava"|"tap"'
```

## Framework-Specific Patterns

### Jest (most common)

**Test file naming:** `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`

**Structure:**
```typescript
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';

describe('UserService', () => {
  let service: UserService;

  beforeEach(() => {
    service = new UserService();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('createUser', () => {
    it('should create a user with valid input', async () => {
      // Arrange
      const input = { name: 'Alice', email: 'alice@example.com' };

      // Act
      const user = await service.createUser(input);

      // Assert
      expect(user).toMatchObject({ name: 'Alice', email: 'alice@example.com' });
      expect(user.id).toBeDefined();
    });

    it('should throw ValidationError for invalid email', async () => {
      // Arrange
      const input = { name: 'Alice', email: 'not-an-email' };

      // Act & Assert
      await expect(service.createUser(input)).rejects.toThrow(ValidationError);
    });
  });
});
```

**Mocking:**
```typescript
// Module mock
jest.mock('./database', () => ({
  query: jest.fn(),
}));

// Spy on existing method
const spy = jest.spyOn(service, 'validate');

// Mock implementation
jest.mocked(database.query).mockResolvedValue([{ id: 1 }]);
```

**Run commands:**
```bash
npx jest --verbose                     # Run all tests
npx jest --testPathPattern=user        # Run tests matching "user"
npx jest --coverage                    # Run with coverage report
npx jest --watchAll                    # Watch mode
```

### Vitest (Vite projects)

**Test file naming:** `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`

**Structure:**
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('ApiClient', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('should fetch data from the API', async () => {
    // Arrange
    const mockFetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ data: 'test' }),
    });
    vi.stubGlobal('fetch', mockFetch);

    // Act
    const result = await fetchData('/api/users');

    // Assert
    expect(mockFetch).toHaveBeenCalledWith('/api/users', expect.any(Object));
    expect(result).toEqual({ data: 'test' });
  });
});
```

**Run commands:**
```bash
npx vitest run                         # Run all tests once
npx vitest run --reporter=verbose      # Verbose output
npx vitest --coverage                  # With coverage
npx vitest                             # Watch mode (default)
```

### Node.js Built-in Test Runner (node:test)

**Test file naming:** `*.test.ts`, `*.test.js`, `test-*.js`

**Structure:**
```typescript
import { describe, it, beforeEach, mock } from 'node:test';
import assert from 'node:assert/strict';

describe('Calculator', () => {
  let calc: Calculator;

  beforeEach(() => {
    calc = new Calculator();
  });

  it('should add two numbers', () => {
    assert.strictEqual(calc.add(2, 3), 5);
  });

  it('should throw for division by zero', () => {
    assert.throws(() => calc.divide(10, 0), {
      message: /division by zero/i,
    });
  });
});
```

**Mocking:**
```typescript
import { mock } from 'node:test';

const mockFn = mock.fn(() => 42);
assert.strictEqual(mockFn(), 42);
assert.strictEqual(mockFn.mock.calls.length, 1);
```

**Run commands:**
```bash
node --test                            # Run all test files
node --test --test-reporter=spec       # Spec reporter
node --test **/*.test.ts               # Specific pattern
npx tsx --test src/**/*.test.ts        # TypeScript with tsx
```

### Mocha + Chai

**Test file naming:** `*.test.ts`, `*.test.js`, `*.spec.ts`, `*.spec.js`

**Structure:**
```typescript
import { expect } from 'chai';
import sinon from 'sinon';

describe('OrderService', () => {
  let sandbox: sinon.SinonSandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('should calculate order total', () => {
    const order = new OrderService();
    const total = order.calculateTotal([
      { price: 10, quantity: 2 },
      { price: 5, quantity: 3 },
    ]);
    expect(total).to.equal(35);
  });
});
```

**Run commands:**
```bash
npx mocha --recursive                  # Run all tests
npx mocha --grep "order"              # Filter tests
npx mocha --reporter spec             # Spec reporter
```

## API and HTTP Testing

### Supertest (Express/Koa/Fastify)
```typescript
import request from 'supertest';
import app from '../src/app';

describe('GET /api/users', () => {
  it('should return 200 with user list', async () => {
    const response = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer test-token')
      .expect(200);

    expect(response.body).toBeInstanceOf(Array);
    expect(response.body[0]).toHaveProperty('id');
  });

  it('should return 401 without auth token', async () => {
    await request(app)
      .get('/api/users')
      .expect(401);
  });
});
```

### Database Testing
```typescript
describe('UserRepository', () => {
  beforeAll(async () => {
    await db.migrate.latest();
  });

  beforeEach(async () => {
    await db.seed.run();  // Reset to known state
  });

  afterAll(async () => {
    await db.destroy();
  });

  it('should find user by email', async () => {
    const user = await repo.findByEmail('test@example.com');
    expect(user).toBeDefined();
    expect(user.email).toBe('test@example.com');
  });
});
```

## Common Patterns

### Environment and Configuration
```typescript
// Use test-specific environment
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'sqlite::memory:';

// Or use dotenv-flow
import 'dotenv-flow/config';
```

### Async Error Testing
```typescript
// Jest/Vitest
await expect(asyncFn()).rejects.toThrow('expected message');

// Node.js built-in
await assert.rejects(asyncFn(), { message: /expected message/ });

// Mocha/Chai
await expect(asyncFn()).to.be.rejectedWith('expected message');
```

### Snapshot Testing (Jest/Vitest)
```typescript
it('should match snapshot', () => {
  const output = generateConfig({ env: 'production' });
  expect(output).toMatchSnapshot();
});
```

### Coverage Configuration
```json
// package.json (Jest)
{
  "jest": {
    "collectCoverageFrom": [
      "src/**/*.{ts,js}",
      "!src/**/*.d.ts",
      "!src/**/index.ts"
    ],
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 80,
        "lines": 80,
        "statements": 80
      }
    }
  }
}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Cannot find module` | Check `tsconfig.json` paths and `moduleNameMapper` in test config |
| `SyntaxError: Cannot use import` | Add `"transform"` config or use `--experimental-vm-modules` |
| Tests hang | Check for open handles with `--detectOpenHandles` (Jest) |
| Flaky async tests | Increase timeout, check for race conditions, use `waitFor` patterns |
| Mock not working | Verify mock is set up before module import, check hoisting behavior |
| TypeScript errors in tests | Ensure test files are included in `tsconfig.json` or have a separate `tsconfig.test.json` |
