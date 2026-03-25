import { describe, it, beforeEach, afterEach } from 'node:test';
import * as assert from 'node:assert/strict';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';

/**
 * Unit tests for the MemoryTool helper functions.
 *
 * These tests validate the pure logic of the memory tool (slugify,
 * sanitizeName, formatTimestamp, parseFrontmatter, escapeYaml) without
 * requiring a running VS Code instance.
 */

// ── Helper function tests (extracted logic) ────────────────────────────

function slugify(text: string): string {
	return text
		.toLowerCase()
		.replace(/[^a-z0-9\s-]/g, '')
		.replace(/\s+/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-|-$/g, '')
		.slice(0, 50);
}

function sanitizeName(name: string): string {
	return name
		.toLowerCase()
		.replace(/[^a-z0-9-]/g, '')
		.slice(0, 30) || 'shared';
}

function sanitizeTag(tag: string): string {
	return tag
		.toLowerCase()
		.replace(/[^a-z0-9-]/g, '')
		.slice(0, 30);
}

function escapeYaml(text: string): string {
	return text.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');
}

function formatTimestamp(date: Date): string {
	const pad = (n: number) => String(n).padStart(2, '0');
	return [
		date.getUTCFullYear(),
		pad(date.getUTCMonth() + 1),
		pad(date.getUTCDate()),
		'-',
		pad(date.getUTCHours()),
		pad(date.getUTCMinutes()),
		pad(date.getUTCSeconds()),
	].join('');
}

interface ParsedMemory {
	agent: string;
	date: string;
	task: string;
	tags: string[];
	outcome: string;
	content: string;
	relativePath: string;
}

function parseFrontmatter(raw: string, fallbackAgent: string): ParsedMemory {
	const mem: ParsedMemory = {
		agent: fallbackAgent,
		date: '',
		task: '',
		tags: [],
		outcome: '',
		content: '',
		relativePath: '',
	};

	const lines = raw.split('\n');
	if (lines[0]?.trim() !== '---') {
		mem.content = raw;
		return mem;
	}

	let endIdx = -1;
	for (let i = 1; i < lines.length; i++) {
		if (lines[i].trim() === '---') {
			endIdx = i;
			break;
		}
	}

	if (endIdx === -1) {
		mem.content = raw;
		return mem;
	}

	const fmLines = lines.slice(1, endIdx);
	for (const line of fmLines) {
		const match = line.match(/^(\w[\w_]*):\s*(.*)$/);
		if (!match) { continue; }
		const [, key, rawVal] = match;
		const val = rawVal.replace(/^["']|["']$/g, '').trim();

		switch (key) {
			case 'agent': mem.agent = val; break;
			case 'date': mem.date = val; break;
			case 'task': mem.task = val; break;
			case 'outcome': mem.outcome = val; break;
			case 'tags': {
				const inner = val.replace(/^\[|\]$/g, '');
				mem.tags = inner
					.split(',')
					.map(t => t.trim())
					.filter(Boolean);
				break;
			}
		}
	}

	mem.content = lines.slice(endIdx + 1).join('\n').trim();
	return mem;
}

// ── Tests ──────────────────────────────────────────────────────────────

describe('MemoryTool helpers', () => {

	describe('slugify', () => {
		it('converts spaces to hyphens', () => {
			assert.strictEqual(slugify('hello world'), 'hello-world');
		});

		it('removes special characters', () => {
			assert.strictEqual(slugify('API Design!@#$ Patterns'), 'api-design-patterns');
		});

		it('collapses multiple hyphens', () => {
			assert.strictEqual(slugify('foo---bar'), 'foo-bar');
		});

		it('trims leading/trailing hyphens', () => {
			assert.strictEqual(slugify('--hello--'), 'hello');
		});

		it('truncates to 50 characters', () => {
			const long = 'a'.repeat(60);
			assert.strictEqual(slugify(long).length, 50);
		});

		it('handles empty string', () => {
			assert.strictEqual(slugify(''), '');
		});
	});

	describe('sanitizeName', () => {
		it('lowercases and strips special chars', () => {
			assert.strictEqual(sanitizeName('Architect'), 'architect');
		});

		it('prevents directory traversal', () => {
			assert.strictEqual(sanitizeName('../etc/passwd'), 'etcpasswd');
		});

		it('defaults to shared for empty result', () => {
			assert.strictEqual(sanitizeName('!!!'), 'shared');
		});

		it('truncates to 30 characters', () => {
			assert.strictEqual(sanitizeName('a'.repeat(40)).length, 30);
		});
	});

	describe('sanitizeTag', () => {
		it('lowercases and strips special chars', () => {
			assert.strictEqual(sanitizeTag('API'), 'api');
		});

		it('allows hyphens', () => {
			assert.strictEqual(sanitizeTag('tech-debt'), 'tech-debt');
		});
	});

	describe('escapeYaml', () => {
		it('escapes double quotes', () => {
			assert.strictEqual(escapeYaml('say "hello"'), 'say \\"hello\\"');
		});

		it('replaces newlines with spaces', () => {
			assert.strictEqual(escapeYaml('line1\nline2'), 'line1 line2');
		});

		it('escapes backslashes', () => {
			assert.strictEqual(escapeYaml('path\\to\\file'), 'path\\\\to\\\\file');
		});
	});

	describe('formatTimestamp', () => {
		it('formats a known date correctly', () => {
			const d = new Date('2026-03-25T10:30:45Z');
			assert.strictEqual(formatTimestamp(d), '20260325-103045');
		});

		it('pads single-digit values', () => {
			const d = new Date('2026-01-05T03:07:09Z');
			assert.strictEqual(formatTimestamp(d), '20260105-030709');
		});
	});

	describe('parseFrontmatter', () => {
		it('parses a standard memory file', () => {
			const raw = [
				'---',
				'agent: architect',
				'date: "2026-03-25T10:00:00Z"',
				'task: "Reviewed API patterns"',
				'tags: [api, validation, rest]',
				'outcome: approved',
				'---',
				'',
				'# API Patterns',
				'',
				'Some content here.',
			].join('\n');

			const result = parseFrontmatter(raw, 'fallback');
			assert.strictEqual(result.agent, 'architect');
			assert.strictEqual(result.date, '2026-03-25T10:00:00Z');
			assert.strictEqual(result.task, 'Reviewed API patterns');
			assert.deepStrictEqual(result.tags, ['api', 'validation', 'rest']);
			assert.strictEqual(result.outcome, 'approved');
			assert.ok(result.content.includes('API Patterns'));
			assert.ok(result.content.includes('Some content here.'));
		});

		it('uses fallback agent when frontmatter has no agent', () => {
			const raw = [
				'---',
				'task: "Some task"',
				'---',
				'Content.',
			].join('\n');

			const result = parseFrontmatter(raw, 'tester');
			assert.strictEqual(result.agent, 'tester');
		});

		it('handles files without frontmatter', () => {
			const raw = '# Just Content\n\nNo frontmatter here.';
			const result = parseFrontmatter(raw, 'shared');
			assert.strictEqual(result.agent, 'shared');
			assert.strictEqual(result.content, raw);
		});

		it('handles empty tags', () => {
			const raw = [
				'---',
				'tags: []',
				'---',
				'Content.',
			].join('\n');

			const result = parseFrontmatter(raw, 'shared');
			assert.deepStrictEqual(result.tags, []);
		});

		it('handles malformed frontmatter (no closing ---)', () => {
			const raw = [
				'---',
				'agent: broken',
				'This never closes',
			].join('\n');

			const result = parseFrontmatter(raw, 'shared');
			assert.strictEqual(result.content, raw);
		});
	});

	describe('Store and recall integration', () => {
		let tmpDir: string;

		beforeEach(() => {
			tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'apex-memory-test-'));
			const memDir = path.join(tmpDir, '.github', 'memory', 'architect');
			fs.mkdirSync(memDir, { recursive: true });
		});

		afterEach(() => {
			fs.rmSync(tmpDir, { recursive: true, force: true });
		});

		it('creates a memory file with correct structure', () => {
			const memDir = path.join(tmpDir, '.github', 'memory', 'architect');
			const content = [
				'---',
				'agent: architect',
				'date: "2026-03-25T10:00:00Z"',
				'task: "Test memory"',
				'tags: [test, integration]',
				'outcome: completed',
				'---',
				'',
				'# Test Memory',
				'',
				'This is test content.',
				'',
			].join('\n');

			const filePath = path.join(memDir, 'test-memory-20260325-100000.md');
			fs.writeFileSync(filePath, content, 'utf-8');

			// Verify file exists and is parseable
			const raw = fs.readFileSync(filePath, 'utf-8');
			const parsed = parseFrontmatter(raw, 'fallback');

			assert.strictEqual(parsed.agent, 'architect');
			assert.strictEqual(parsed.task, 'Test memory');
			assert.deepStrictEqual(parsed.tags, ['test', 'integration']);
			assert.strictEqual(parsed.outcome, 'completed');
			assert.ok(parsed.content.includes('This is test content.'));
		});

		it('scans directory for memory files', () => {
			const memDir = path.join(tmpDir, '.github', 'memory', 'architect');

			// Create two memory files
			for (const name of ['mem-a-20260325-100000.md', 'mem-b-20260325-110000.md']) {
				fs.writeFileSync(
					path.join(memDir, name),
					'---\nagent: architect\ntask: "Task"\ntags: [test]\noutcome: completed\n---\nContent',
					'utf-8'
				);
			}

			// Also create a TEMPLATE.md that should be skipped
			fs.writeFileSync(path.join(memDir, 'TEMPLATE.md'), '# Template', 'utf-8');

			const files = fs.readdirSync(memDir)
				.filter(f => f.endsWith('.md') && f !== 'TEMPLATE.md' && f !== 'README.md');

			assert.strictEqual(files.length, 2);
		});

		it('ignores directories without .md files', () => {
			const emptyDir = path.join(tmpDir, '.github', 'memory', 'empty-agent');
			fs.mkdirSync(emptyDir, { recursive: true });
			fs.writeFileSync(path.join(emptyDir, '.gitkeep'), '', 'utf-8');

			const files = fs.readdirSync(emptyDir)
				.filter(f => f.endsWith('.md') && f !== 'TEMPLATE.md' && f !== 'README.md');

			assert.strictEqual(files.length, 0);
		});
	});
});
