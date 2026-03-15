---
name: implementation-patterns
description: "Provides best practices for code implementation including error handling, validation, security patterns, and clean code principles. Use when writing or reviewing production code."
---

# Implementation Patterns Skill

When implementing code, follow these patterns and principles.

## Security-First Patterns

### Input Validation
- Validate ALL inputs at system boundaries (API endpoints, CLI args, file reads, env vars)
- Use allowlists over denylists for input validation
- Sanitize data before storage or display
- Never trust client-side validation alone

### Injection Prevention
- Use parameterized queries for all database operations — never string concatenation
- Escape output appropriate to context (HTML, SQL, shell, URL)
- Validate and sanitize file paths — prevent directory traversal

### Authentication & Authorization
- Check authorization on every request, not just at the UI level
- Use constant-time comparison for sensitive values
- Never log secrets, tokens, or passwords

## Error Handling Patterns

### Structured Errors
```
// Good: Errors carry context
class AppError extends Error {
  constructor(message, { code, statusCode, context }) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.context = context;
  }
}

// Good: Errors are caught at boundaries
app.use((err, req, res, next) => {
  logger.error({ err, requestId: req.id });
  res.status(err.statusCode || 500).json({ error: err.code || 'INTERNAL_ERROR' });
});
```

### Never Silently Swallow Errors
```
// BAD
try { doSomething(); } catch (e) { /* ignore */ }

// GOOD
try { doSomething(); } catch (e) { logger.warn('Non-critical failure in doSomething', { error: e }); }
```

## Clean Code Principles

### Function Design
- Functions should do one thing
- Keep functions short (< 30 lines is a good target)
- Prefer descriptive names over comments
- Limit parameters (3 max; use an options object for more)

### Module Design
- One module = one responsibility
- Explicit exports; no barrel files that re-export everything
- Dependencies flow inward (domain doesn't depend on infrastructure)

### Naming
- Booleans: `isActive`, `hasPermission`, `canDelete` (prefix with is/has/can/should)
- Functions: verb + noun (`createUser`, `validateInput`, `fetchOrders`)
- Constants: `UPPER_SNAKE_CASE` for true constants
- No abbreviations in public APIs

## Testing Considerations During Implementation
- Write code that's testable: inject dependencies, avoid global state
- Prefer pure functions where possible
- Design interfaces/contracts for external dependencies (makes mocking easy)
- Keep side effects at the edges of the system
