import DOMPurify from 'dompurify';
import { marked } from 'marked';

/**
 * Render Markdown while treating all input as untrusted.
 *
 * Blog content and AI responses can contain attacker-controlled HTML. Marked
 * intentionally permits raw HTML, so every rendered result must pass through
 * an allowlist sanitizer before it reaches dangerouslySetInnerHTML.
 */
export const renderSafeMarkdown = (source: string | null | undefined): string => {
  const rendered = marked.parse(source ?? '', { async: false }) as string;

  return DOMPurify.sanitize(rendered, {
    USE_PROFILES: { html: true },
    FORBID_TAGS: ['script', 'style', 'iframe', 'object', 'embed', 'form'],
    FORBID_ATTR: ['style'],
  });
};
