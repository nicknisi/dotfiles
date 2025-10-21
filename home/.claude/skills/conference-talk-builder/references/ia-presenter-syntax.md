# iA Presenter Markdown Syntax

Quick reference for creating slides in iA Presenter.

## CRITICAL: Tabbing Rules

**MUST be tabbed to appear on slides:**
- Regular paragraphs
- Lists (bullets, numbered, tasks)
- Block quotes
- Definition lists
- Tables
- Images

**NO TAB needed (appear on slides automatically):**
- Headers (`#`, `##`, `###`, etc.)
- Horizontal rules (`---`)
- Fenced code blocks (` ``` `)
- Math blocks (`$$`)

**Never appears on slides:**
- Comments (`//`)

## Slide Structure

### Create New Slides
```markdown
---
```
Use horizontal rules to split slides. No tab needed.

### Headings
```markdown
# Heading 1
## Heading 2
### Heading 3
```
Headers appear on slides automatically. No tab needed.

## Text on Slides

Regular paragraphs MUST be tabbed to appear on slides:

```markdown
⇥This text will appear on the slide.
⇥
⇥This is another paragraph on the slide.
```

Without tabs, text is spoken only (speaker notes):
```markdown
This text is only for the speaker to read.
```

## Text Formatting

Inside tabbed paragraphs:
```markdown
⇥**bold text**
⇥*italic text*
⇥~~strikethrough~~
⇥==highlighted text==
```

Superscript and subscript:
```markdown
⇥100m^2
⇥y^(a+b)^
⇥x~z
```

## Lists

Lists MUST be tabbed to appear on slides:

```markdown
⇥- Item one
⇥- Item two
⇥- Item three
```

Numbered lists:
```markdown
⇥1. First item
⇥2. Second item
⇥3. Third item
```

Task lists:
```markdown
⇥- [ ] Unchecked task
⇥- [x] Completed task
```

Nested lists:
```markdown
⇥- Main item
⇥    - Nested item
⇥    - Another nested item
```

## Block Quotes

Block quotes MUST be tabbed:

```markdown
⇥> This quote appears on the slide
```

## Definition Lists

Definition lists MUST be tabbed:

```markdown
⇥Term
⇥: Definition of the term
⇥: Another definition
```

## Code

### Inline Code
```markdown
⇥Use `keyword` for inline code within a paragraph
```

### Code Blocks
Fenced code blocks appear on slides automatically. NO TAB needed:

````markdown
```typescript
function hello() {
  console.log("Hello");
}
```
````

Language tags are optional but recommended for syntax highlighting.

## Images

Images MUST be tabbed and added to Media Manager first:

```markdown
⇥![Alt text](filename.png)
```

Note: Encode spaces as `%20`. Omit leading slash.

## Tables

Tables MUST be tabbed:

```markdown
⇥| Name | Price | Tax |
⇥|:--|--:|--:|
⇥| Widget | 10$ | 1$ |
⇥| Gift | 0$ ||
```

Alignment:
- Left: `:--`
- Right: `--:`
- Center: `:-:`

## Math

Math blocks appear on slides automatically. NO TAB needed:

Inline math (needs surrounding text tabbed):
```markdown
⇥An example of math $x+y^2$ within text.
```

Block math:
```markdown
$$
\displaystyle \frac{1}{x}
$$
```

## Comments

Comments are only visible in the editor:

```markdown
// This is a speaker note or reminder
```

## Links and Footnotes

Links within tabbed content:
```markdown
⇥Visit [this site](https://example.com) for more info.
```

Footnotes:
```markdown
⇥Text with footnote[^1].
[^1]: Footnote content.
```

Citations:
```markdown
⇥Statement with source[p. 23][#Doe:2006].
[#Doe:2006]: Author. *Title*. Publisher, Year.
```

## Complete Slide Example

```markdown
# Slide Title

// This is a speaker note - not visible on slide

⇥This paragraph appears on the slide because it's tabbed.

⇥Key points:
⇥- First point
⇥- Second point
⇥- Third point

```typescript
// Code blocks don't need tabs
function example() {
  return "This appears on slide automatically";
}
```

---

## Next Slide

⇥More content here...
```

## Best Practices

1. Tab all regular content (paragraphs, lists, quotes, tables, images)
2. Don't tab headers, code blocks, or math blocks
3. Use comments for speaker notes
4. Break complex code across multiple slides
5. Test that all visible content is properly tabbed
