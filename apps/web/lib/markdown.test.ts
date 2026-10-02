/* @vitest-environment jsdom */
import { describe, expect, it } from 'vitest';
import { renderSafeMarkdown } from './markdown';

describe('renderSafeMarkdown', () => {
  it('removes script-capable HTML from stored Markdown', () => {
    const html = renderSafeMarkdown('<script>alert(1)</script><img src="x" onerror="alert(2)">Safe');

    expect(html).not.toContain('<script');
    expect(html).not.toContain('onerror');
    expect(html).toContain('Safe');
  });

  it('removes javascript URLs while preserving safe Markdown links', () => {
    const unsafe = renderSafeMarkdown('[bad](javascript:alert(1))');
    const safe = renderSafeMarkdown('[ACCF](https://example.com)');

    expect(unsafe.toLowerCase()).not.toContain('javascript:');
    expect(safe).toContain('https://example.com');
  });
});
