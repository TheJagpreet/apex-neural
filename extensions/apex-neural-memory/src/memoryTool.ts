import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';

/** Input schema for the memory tool */
interface IMemoryToolInput {
	action: 'store' | 'recall' | 'list';
	agent?: string;
	task?: string;
	tags?: string[];
	content?: string;
	outcome?: string;
	query?: string;
}

/**
 * Apex Neural Memory Tool — stores, recalls, and lists workspace-local memories.
 *
 * Memories are saved as markdown files with YAML frontmatter in
 * `<workspace>/.github/memory/<agent>/` directories.
 */
export class MemoryTool implements vscode.LanguageModelTool<IMemoryToolInput> {

	async invoke(
		options: vscode.LanguageModelToolInvocationOptions<IMemoryToolInput>,
		token: vscode.CancellationToken,
	): Promise<vscode.LanguageModelToolResult> {
		const input = options.input;

		switch (input.action) {
			case 'store':
				return this.store(input, token);
			case 'recall':
				return this.recall(input, token);
			case 'list':
				return this.list(input, token);
			default:
				return new vscode.LanguageModelToolResult([
					new vscode.LanguageModelTextPart(
						`Unknown action: "${input.action}". Use "store", "recall", or "list".`
					),
				]);
		}
	}

	async prepareInvocation(
		options: vscode.LanguageModelToolInvocationPrepareOptions<IMemoryToolInput>,
		_token: vscode.CancellationToken,
	) {
		const { action, agent, task, query } = options.input;
		let message: string;

		switch (action) {
			case 'store':
				message = `Store memory for agent "${agent ?? 'shared'}": ${task ?? '(no task)'}`;
				break;
			case 'recall':
				message = `Search memories: "${query ?? '(all)'}"`;
				break;
			case 'list':
				message = `List memories${agent ? ` for agent "${agent}"` : ''}`;
				break;
			default:
				message = `Memory tool: ${action}`;
		}

		return {
			invocationMessage: message,
		};
	}

	// ── Store ──────────────────────────────────────────────────────────

	private async store(
		input: IMemoryToolInput,
		_token: vscode.CancellationToken,
	): Promise<vscode.LanguageModelToolResult> {
		const workspaceRoot = this.getWorkspaceRoot();
		if (!workspaceRoot) {
			return this.errorResult('No workspace folder is open. Cannot store memory.');
		}

		const agent = this.sanitizeName(input.agent ?? 'shared');
		const task = input.task ?? 'Untitled memory';
		const tags = (input.tags ?? []).map(t => this.sanitizeTag(t));
		const content = input.content ?? '';
		const outcome = input.outcome ?? 'completed';

		// Build the memory directory path
		const memoryDir = path.join(workspaceRoot, '.github', 'memory', agent);
		await fs.promises.mkdir(memoryDir, { recursive: true });

		// Generate filename: <context-summary>-<YYYYMMDD-HHMMSS>.md
		const now = new Date();
		const timestamp = this.formatTimestamp(now);
		const slug = this.slugify(task);
		const filename = `${slug}-${timestamp}.md`;
		const filePath = path.join(memoryDir, filename);

		// Build YAML frontmatter
		const isoDate = now.toISOString().replace(/\.\d{3}Z$/, 'Z');
		const tagsYaml = tags.length > 0
			? `[${tags.join(', ')}]`
			: '[]';

		const fileContent = [
			'---',
			`agent: ${agent}`,
			`date: "${isoDate}"`,
			`task: "${this.escapeYaml(task)}"`,
			`tags: ${tagsYaml}`,
			`outcome: ${outcome}`,
			'---',
			'',
			content,
			'',
		].join('\n');

		await fs.promises.writeFile(filePath, fileContent, 'utf-8');

		const relativePath = path.relative(workspaceRoot, filePath);

		return new vscode.LanguageModelToolResult([
			new vscode.LanguageModelTextPart(
				`Memory stored successfully.\n` +
				`  File: ${relativePath}\n` +
				`  Agent: ${agent}\n` +
				`  Task: ${task}\n` +
				`  Tags: ${tags.join(', ') || '(none)'}\n` +
				`  Outcome: ${outcome}`
			),
		]);
	}

	// ── Recall ─────────────────────────────────────────────────────────

	private async recall(
		input: IMemoryToolInput,
		_token: vscode.CancellationToken,
	): Promise<vscode.LanguageModelToolResult> {
		const workspaceRoot = this.getWorkspaceRoot();
		if (!workspaceRoot) {
			return this.errorResult('No workspace folder is open. Cannot recall memories.');
		}

		const memoryRoot = path.join(workspaceRoot, '.github', 'memory');
		if (!fs.existsSync(memoryRoot)) {
			return new vscode.LanguageModelToolResult([
				new vscode.LanguageModelTextPart('No memories found. The .github/memory/ directory does not exist yet.'),
			]);
		}

		const query = (input.query ?? '').toLowerCase();
		const agentFilter = input.agent ? this.sanitizeName(input.agent) : undefined;

		const memories = await this.scanMemories(memoryRoot, agentFilter);

		if (memories.length === 0) {
			return new vscode.LanguageModelToolResult([
				new vscode.LanguageModelTextPart(`No memories found${agentFilter ? ` for agent "${agentFilter}"` : ''}.`),
			]);
		}

		// Filter by query (match against tags, task, and content)
		const matches = query
			? memories.filter(m =>
				m.task.toLowerCase().includes(query) ||
				m.tags.some(t => t.toLowerCase().includes(query)) ||
				m.content.toLowerCase().includes(query) ||
				m.agent.toLowerCase().includes(query)
			)
			: memories;

		if (matches.length === 0) {
			return new vscode.LanguageModelToolResult([
				new vscode.LanguageModelTextPart(`No memories match query "${input.query}".`),
			]);
		}

		// Sort by date descending (newest first)
		matches.sort((a, b) => b.date.localeCompare(a.date));

		// Limit to 10 most recent matches
		const limited = matches.slice(0, 10);
		const resultParts: string[] = [
			`Found ${matches.length} matching memor${matches.length === 1 ? 'y' : 'ies'}${matches.length > 10 ? ' (showing 10 most recent)' : ''}:`,
			'',
		];

		for (const mem of limited) {
			resultParts.push(
				`### ${mem.relativePath}`,
				`- **Agent**: ${mem.agent}`,
				`- **Date**: ${mem.date}`,
				`- **Task**: ${mem.task}`,
				`- **Tags**: ${mem.tags.join(', ') || '(none)'}`,
				`- **Outcome**: ${mem.outcome}`,
				'',
				mem.content.slice(0, 500) + (mem.content.length > 500 ? '\n...(truncated)' : ''),
				'',
				'---',
				'',
			);
		}

		return new vscode.LanguageModelToolResult([
			new vscode.LanguageModelTextPart(resultParts.join('\n')),
		]);
	}

	// ── List ───────────────────────────────────────────────────────────

	private async list(
		input: IMemoryToolInput,
		_token: vscode.CancellationToken,
	): Promise<vscode.LanguageModelToolResult> {
		const workspaceRoot = this.getWorkspaceRoot();
		if (!workspaceRoot) {
			return this.errorResult('No workspace folder is open. Cannot list memories.');
		}

		const memoryRoot = path.join(workspaceRoot, '.github', 'memory');
		if (!fs.existsSync(memoryRoot)) {
			return new vscode.LanguageModelToolResult([
				new vscode.LanguageModelTextPart('No memories found. The .github/memory/ directory does not exist yet.'),
			]);
		}

		const agentFilter = input.agent ? this.sanitizeName(input.agent) : undefined;
		const memories = await this.scanMemories(memoryRoot, agentFilter);

		if (memories.length === 0) {
			return new vscode.LanguageModelToolResult([
				new vscode.LanguageModelTextPart(`No memories found${agentFilter ? ` for agent "${agentFilter}"` : ''}.`),
			]);
		}

		// Sort by date descending
		memories.sort((a, b) => b.date.localeCompare(a.date));

		// Group by agent
		const byAgent = new Map<string, typeof memories>();
		for (const mem of memories) {
			const group = byAgent.get(mem.agent) ?? [];
			group.push(mem);
			byAgent.set(mem.agent, group);
		}

		const resultParts: string[] = [
			`Total memories: ${memories.length}`,
			'',
		];

		for (const [agent, agentMemories] of byAgent) {
			resultParts.push(`## ${agent} (${agentMemories.length})`);
			for (const mem of agentMemories) {
				resultParts.push(
					`- **${mem.relativePath}** — ${mem.task} [${mem.tags.join(', ')}] (${mem.outcome}, ${mem.date})`
				);
			}
			resultParts.push('');
		}

		return new vscode.LanguageModelToolResult([
			new vscode.LanguageModelTextPart(resultParts.join('\n')),
		]);
	}

	// ── Helpers ────────────────────────────────────────────────────────

	private getWorkspaceRoot(): string | undefined {
		const folders = vscode.workspace.workspaceFolders;
		return folders?.[0]?.uri.fsPath;
	}

	private errorResult(message: string): vscode.LanguageModelToolResult {
		return new vscode.LanguageModelToolResult([
			new vscode.LanguageModelTextPart(`Error: ${message}`),
		]);
	}

	/** Scan .github/memory/ for markdown files and parse their frontmatter */
	private async scanMemories(
		memoryRoot: string,
		agentFilter?: string,
	): Promise<ParsedMemory[]> {
		const results: ParsedMemory[] = [];

		let dirs: string[];
		if (agentFilter) {
			const agentDir = path.join(memoryRoot, agentFilter);
			dirs = fs.existsSync(agentDir) ? [agentDir] : [];
		} else {
			const entries = await fs.promises.readdir(memoryRoot, { withFileTypes: true });
			dirs = entries
				.filter(e => e.isDirectory())
				.map(e => path.join(memoryRoot, e.name));
		}

		for (const dir of dirs) {
			const agentName = path.basename(dir);
			const files = await fs.promises.readdir(dir).catch(() => [] as string[]);

			for (const file of files) {
				if (!file.endsWith('.md') || file === 'TEMPLATE.md' || file === 'README.md') {
					continue;
				}

				const filePath = path.join(dir, file);
				const raw = await fs.promises.readFile(filePath, 'utf-8');
				const parsed = this.parseFrontmatter(raw, agentName);
				const workspaceRoot = path.resolve(memoryRoot, '..', '..');
				parsed.relativePath = path.relative(workspaceRoot, filePath);
				results.push(parsed);
			}
		}

		return results;
	}

	/** Parse YAML frontmatter from a markdown memory file */
	private parseFrontmatter(raw: string, fallbackAgent: string): ParsedMemory {
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

		// Find end of frontmatter
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

		// Parse frontmatter fields (simple key: value parsing)
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
					// Parse [tag1, tag2, tag3]
					const inner = val.replace(/^\[|\]$/g, '');
					mem.tags = inner
						.split(',')
						.map(t => t.trim())
						.filter(Boolean);
					break;
				}
			}
		}

		// Everything after frontmatter is content
		mem.content = lines.slice(endIdx + 1).join('\n').trim();
		return mem;
	}

	/** Format a Date as YYYYMMDD-HHMMSS */
	private formatTimestamp(date: Date): string {
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

	/** Convert a task description to a kebab-case slug */
	private slugify(text: string): string {
		return text
			.toLowerCase()
			.replace(/[^a-z0-9\s-]/g, '')
			.replace(/\s+/g, '-')
			.replace(/-+/g, '-')
			.replace(/^-|-$/g, '')
			.slice(0, 50);
	}

	/** Sanitize an agent name to prevent directory traversal */
	private sanitizeName(name: string): string {
		return name
			.toLowerCase()
			.replace(/[^a-z0-9-]/g, '')
			.slice(0, 30) || 'shared';
	}

	/** Sanitize a tag value */
	private sanitizeTag(tag: string): string {
		return tag
			.toLowerCase()
			.replace(/[^a-z0-9-]/g, '')
			.slice(0, 30);
	}

	/** Escape a string for safe YAML inclusion */
	private escapeYaml(text: string): string {
		return text.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');
	}
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
