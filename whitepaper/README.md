# Apex Neural — Whitepaper

This directory contains the formal whitepaper for the Apex Neural project.

## Contents

| File | Description |
|------|-------------|
| [`WHITEPAPER.md`](./WHITEPAPER.md) | The full whitepaper in Markdown format |
| [`diagrams/`](./diagrams/) | Supplementary diagram source files |

## Reading the Whitepaper

The whitepaper is written in standard Markdown with embedded [Mermaid](https://mermaid.js.org/) diagrams. It can be read directly on GitHub, which renders both Markdown and Mermaid natively.

For local viewing, any Markdown previewer that supports Mermaid will render the diagrams correctly. Recommended options include:

- **VS Code** with the built-in Markdown preview (Mermaid support is included by default in VS Code 1.100+)
- **GitHub** web interface (renders Mermaid in `.md` files automatically)

## Exporting to PDF

To export the whitepaper to PDF, use one of the following methods:

1. **VS Code**: Install the [Markdown PDF](https://marketplace.visualstudio.com/items?itemName=yzane.markdown-pdf) extension, open `WHITEPAPER.md`, and run the `Markdown PDF: Export (pdf)` command.
2. **Pandoc**: Run `pandoc WHITEPAPER.md -o WHITEPAPER.pdf --pdf-engine=xelatex` (requires Pandoc and a LaTeX distribution).
3. **GitHub**: Print the rendered page from the GitHub web interface using the browser's "Print to PDF" function.

> **Note:** Mermaid diagrams may not render in all PDF export tools. For best results, use a tool with native Mermaid support or pre-render diagrams to SVG/PNG.

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-03-30 | Initial formal whitepaper |
