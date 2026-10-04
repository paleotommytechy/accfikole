import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  getUser: vi.fn(),
  maybeSingle: vi.fn(),
}));

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    auth: {
      getUser: mocks.getUser,
    },
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          maybeSingle: mocks.maybeSingle,
        })),
      })),
    })),
  })),
}));

import {
  requireAiUser,
  validateInlineFile,
  validateText,
} from './_security';

const createResponse = () => {
  const response: any = {
    statusCode: 200,
    body: null,
    headers: {} as Record<string, string>,
  };

  response.status = vi.fn((code: number) => {
    response.statusCode = code;
    return response;
  });
  response.json = vi.fn((body: unknown) => {
    response.body = body;
    return response;
  });
  response.setHeader = vi.fn((name: string, value: string) => {
    response.headers[name] = value;
  });

  return response;
};

describe('AI API security boundary', () => {
  beforeEach(() => {
    process.env.SUPABASE_URL = 'https://example.supabase.co';
    process.env.SUPABASE_ANON_KEY = 'public-anon-key';
    mocks.getUser.mockReset();
    mocks.maybeSingle.mockReset();
  });

  it('rejects unauthenticated requests before provider access', async () => {
    const res = createResponse();

    const user = await requireAiUser({ headers: {} }, res);

    expect(user).toBeNull();
    expect(res.statusCode).toBe(401);
  });

  it('accepts a verified Supabase session', async () => {
    const user = { id: 'user-authenticated' };
    mocks.getUser.mockResolvedValue({ data: { user }, error: null });
    const res = createResponse();

    const result = await requireAiUser(
      { headers: { authorization: 'Bearer valid-token' } },
      res,
      { maxRequests: 5 },
    );

    expect(result).toEqual(user);
    expect(res.statusCode).toBe(200);
  });

  it('enforces role authorization when a role is required', async () => {
    const user = { id: 'user-role-denied' };
    mocks.getUser.mockResolvedValue({ data: { user }, error: null });
    mocks.maybeSingle.mockResolvedValue({ data: { role: 'member' }, error: null });
    const res = createResponse();

    const result = await requireAiUser(
      { headers: { authorization: 'Bearer valid-token' } },
      res,
      { allowedRoles: ['admin'] },
    );

    expect(result).toBeNull();
    expect(res.statusCode).toBe(403);
  });

  it('rate limits repeated authenticated requests', async () => {
    const user = { id: 'user-rate-limit' };
    mocks.getUser.mockResolvedValue({ data: { user }, error: null });

    const first = createResponse();
    const second = createResponse();

    expect(await requireAiUser(
      { headers: { authorization: 'Bearer valid-token' } },
      first,
      { maxRequests: 1, windowMs: 60_000 },
    )).toEqual(user);

    expect(await requireAiUser(
      { headers: { authorization: 'Bearer valid-token' } },
      second,
      { maxRequests: 1, windowMs: 60_000 },
    )).toBeNull();

    expect(second.statusCode).toBe(429);
    expect(second.headers['Retry-After']).toBeDefined();
  });

  it('rejects invalid, oversized, and unsupported inline files', () => {
    expect(() => validateInlineFile('not base64!', 'application/pdf')).toThrow(/valid base64/i);
    expect(() => validateInlineFile(
      'QUJD',
      'text/html',
      { allowedMimeTypes: ['application/pdf'] },
    )).toThrow(/unsupported file type/i);
    expect(() => validateInlineFile(
      'A'.repeat(4096),
      'application/pdf',
      { maxBytes: 16 },
    )).toThrow(/too large/i);
  });

  it('enforces text input limits', () => {
    expect(validateText(' hello ', 'Prompt', 10)).toBe('hello');
    expect(() => validateText('', 'Prompt', 10)).toThrow(/required/i);
    expect(() => validateText('too long', 'Prompt', 3)).toThrow(/exceeds/i);
  });
});
