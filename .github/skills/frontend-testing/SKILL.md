---
name: frontend-testing
description: "Provides frontend and end-to-end testing strategies using the Microsoft Playwright MCP server. Use when testing web UIs, browser interactions, accessibility, or visual regressions."
---

# Frontend Testing Skill — Playwright MCP

When testing frontend applications or performing end-to-end browser testing, use the **Playwright MCP server** configured in `.vscode/mcp.json`.

## Prerequisites

The workspace must have the Playwright MCP server configured:

```json
// .vscode/mcp.json
{
  "servers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "type": "stdio"
    }
  }
}
```

Ensure Node.js 18+ is installed. The MCP server auto-downloads the latest `@playwright/mcp` on first run.

## Available Playwright MCP Tools

The Playwright MCP server exposes these tool categories through the Model Context Protocol:

### Navigation and Interaction
| Tool | Purpose |
|------|---------|
| `browser_navigate` | Navigate to a URL |
| `browser_click` | Click an element (by text, CSS selector, or coordinates) |
| `browser_type` | Type text into an input field |
| `browser_select_option` | Select from a dropdown |
| `browser_hover` | Hover over an element |
| `browser_drag` | Drag and drop between two elements |
| `browser_press_key` | Press keyboard keys |

### Observation and Assertion
| Tool | Purpose |
|------|---------|
| `browser_snapshot` | Capture an accessibility snapshot (DOM tree) |
| `browser_take_screenshot` | Take a PNG/JPEG screenshot of the page or element |
| `browser_console_messages` | Retrieve browser console messages |
| `browser_network_requests` | List all network requests since page load |

### Tab and File Management
| Tool | Purpose |
|------|---------|
| `browser_tab_list` | List all open browser tabs |
| `browser_tab_new` | Open a new tab |
| `browser_tab_select` | Switch to a specific tab |
| `browser_tab_close` | Close a tab |
| `browser_file_upload` | Upload files to a file input element |

### Page Management
| Tool | Purpose |
|------|---------|
| `browser_wait` | Wait for text to appear/disappear or a timeout |
| `browser_resize` | Resize the browser window |
| `browser_evaluate` | Execute JavaScript in the browser context |
| `browser_navigate_back` | Navigate back in browser history |

## Testing Strategy with Playwright MCP

### Step 1: Identify What to Test
- **Critical user flows**: Login, registration, checkout, form submissions
- **Component interactions**: Buttons, dropdowns, modals, navigation
- **Responsive layouts**: Test at multiple viewport sizes
- **Accessibility**: Use `browser_snapshot` for accessibility tree validation
- **Error states**: 404 pages, network failures, form validation errors

### Step 2: Write E2E Tests
Use the Playwright MCP tools to drive browser interactions:

```
1. browser_navigate  ->  open the application URL
2. browser_snapshot  ->  verify the page loaded correctly
3. browser_click / browser_type  ->  interact with the UI
4. browser_snapshot  ->  verify the expected state change
5. browser_take_screenshot  ->  capture visual evidence
```

### Step 3: Validation Patterns

#### Accessibility Snapshot Validation
Use `browser_snapshot` to get the accessibility tree and verify:
- Expected elements are present with correct roles
- Text content matches expectations
- Interactive elements are properly labeled
- Focus order is logical

#### Visual Regression
Use `browser_take_screenshot` to capture and compare:
- Full page screenshots at key states
- Element-level screenshots for component testing
- Screenshots at multiple viewport sizes for responsive testing

#### Network Validation
Use `browser_network_requests` to verify:
- API calls are made to expected endpoints
- Request methods and payloads are correct
- No unexpected failing requests (4xx/5xx)
- Authentication tokens are sent correctly

#### Console Error Detection
Use `browser_console_messages` to check:
- No unexpected JavaScript errors
- No unhandled promise rejections
- Expected log messages are present

### Step 4: Cross-Browser Considerations
The Playwright MCP server uses Chromium by default. For cross-browser testing:
- Test primary flows in the default Chromium browser
- Document any browser-specific behavior for manual verification
- Focus automated tests on functionality, not pixel-perfect rendering

## Common Frontend Test Scenarios

### Form Validation
```
1. Navigate to the form page
2. Submit empty form  ->  verify validation errors appear
3. Fill invalid data  ->  verify field-specific errors
4. Fill valid data  ->  verify successful submission
5. Screenshot each state for evidence
```

### Authentication Flow
```
1. Navigate to login page
2. Enter invalid credentials  ->  verify error message
3. Enter valid credentials  ->  verify redirect to dashboard
4. Check network requests for proper auth token handling
5. Verify protected routes are accessible after login
```

### Responsive Layout
```
1. Resize browser to mobile viewport (375x667)
2. Snapshot  ->  verify mobile layout elements
3. Resize to tablet viewport (768x1024)
4. Snapshot  ->  verify tablet layout elements
5. Resize to desktop viewport (1440x900)
6. Snapshot  ->  verify desktop layout elements
```

### Accessibility Audit
```
1. Navigate to each key page
2. Take accessibility snapshot
3. Verify all interactive elements have accessible names
4. Verify heading hierarchy is correct
5. Verify images have alt text
6. Check for sufficient color contrast in screenshots
```

## Error Handling

- If the Playwright MCP server is not running, the tools will not be available -- check `.vscode/mcp.json` configuration
- If `npx @playwright/mcp@latest` fails, ensure Node.js 18+ is installed and network access is available
- If browser launch fails, check that no other Playwright instances are blocking the browser
- For headless environments (CI), the MCP server runs headless by default
