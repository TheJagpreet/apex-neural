---
name: test-strategy
description: "Provides testing strategies, patterns, and best practices. Use when creating test plans, writing tests, or reviewing test coverage."
---

# Test Strategy Skill

When creating tests or test plans, follow this structured approach.

## Test Pyramid

Prioritize tests in this order (most to fewest):
1. **Unit tests**: Fast, isolated, test single functions/methods
2. **Integration tests**: Test component interactions, API contracts
3. **End-to-end tests**: Full workflow tests (use sparingly)

For language-specific and domain-specific testing guidance, also see:
- **frontend-testing** skill — Playwright MCP-based browser and E2E testing
- **nodejs-testing** skill — Node.js/TypeScript testing patterns (Jest, Vitest, Mocha, node:test)
- **python-testing** skill — Python testing patterns (pytest, Django, Flask, FastAPI)

## Discovering Project Test Setup

Before writing tests, always discover the existing setup:

```powershell
# Find test config files
Get-ChildItem -Recurse -Include "jest.config*","vitest.config*","pytest.ini","setup.cfg","conftest.py","*_test.go","*.test.*" | Select-Object -First 20 -ExpandProperty FullName

# Find existing test files to learn patterns
Get-ChildItem -Recurse -Include "*.test.*","*_test.*","test_*" | Where-Object { $_.FullName -match 'test' } | Select-Object -First 20 -ExpandProperty FullName
```

Read at least 2-3 existing test files to understand:
- Import patterns
- Test structure (describe/it, test functions, test classes)
- Assertion library (`expect`, `assert`, custom matchers)
- Mocking approach (jest.mock, unittest.mock, testify/mock)
- Setup/teardown patterns (beforeEach, setUp, fixtures)

## Test Writing Patterns

### Arrange-Act-Assert (AAA)
```
test('should calculate total with tax', () => {
  // Arrange
  const items = [{ price: 100 }, { price: 200 }];
  const taxRate = 0.1;

  // Act
  const total = calculateTotal(items, taxRate);

  // Assert
  expect(total).toBe(330);
});
```

### Test Naming Convention
Use descriptive names that document behavior:
- `should [expected behavior] when [condition]`
- `[method] returns [expected] for [input]`
- `[method] throws [error] when [condition]`

### Edge Cases to Always Test
- Empty inputs (null, undefined, empty string, empty array)
- Boundary values (0, -1, MAX_INT, empty collections)
- Invalid types (wrong type arguments)
- Error paths (network failures, file not found, permission denied)
- Concurrent access (if applicable)

### Mocking Guidelines
- Mock external dependencies (APIs, databases, file system)
- Don't mock the unit under test
- Don't mock value objects or simple data structures
- Prefer fakes/stubs over complex mock setups
- Verify mock interactions sparingly (prefer state-based testing)

## Test Coverage Targets
- New code: aim for 80%+ line coverage
- Critical paths (auth, payment, data validation): aim for 95%+
- Utility functions: aim for 100%

## Running Tests
Always run tests and capture output:
```powershell
# Common test commands by ecosystem
npm test              # Node.js
npx jest --verbose    # Jest specifically
python -m pytest -v   # Python
go test ./... -v      # Go
cargo test            # Rust
mvn test              # Java/Maven
```

## Failure Analysis
When tests fail, analyze in this order:
1. Read the error message and stack trace carefully
2. Check if it's a test setup issue (missing mock, wrong fixture)
3. Check if it's an actual implementation bug
4. Check if the test expectation is wrong (based on updated requirements)
5. Never change a correct test to make it pass — fix the implementation instead
