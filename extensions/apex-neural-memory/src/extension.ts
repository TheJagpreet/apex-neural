import * as vscode from 'vscode';
import { MemoryTool } from './memoryTool';

export function activate(context: vscode.ExtensionContext) {
	context.subscriptions.push(
		vscode.lm.registerTool('apex_neural_memory', new MemoryTool())
	);
}

export function deactivate() {
	// No cleanup needed
}
