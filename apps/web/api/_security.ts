import { createClient, type User } from '@supabase/supabase-js';

type ApiSecurityOptions = {
  allowedRoles?: string[];
  maxRequests?: number;
  windowMs?: number;
};

type RateBucket = {
  count: number;
  resetAt: number;
};

declare global {
  // Reuse rate buckets across warm serverless invocations. This is intentionally
  // a first-line abuse control; platform/WAF limits can be layered on top.
  // eslint-disable-next-line no-var
  var __accfAiRateBuckets: Map<string, RateBucket> | undefined;
}

const rateBuckets = globalThis.__accfAiRateBuckets ?? new Map<string, RateBucket>();
globalThis.__accfAiRateBuckets = rateBuckets;

const getBearerToken = (req: any): string | null => {
  const authorization = req.headers?.authorization;
  if (typeof authorization !== 'string') return null;

  const [scheme, token] = authorization.trim().split(/\s+/, 2);
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
};

const getServerSupabaseConfig = () => {
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error('Server Supabase configuration is missing.');
  }

  return { url, anonKey };
};

const consumeRateLimit = (
  key: string,
  maxRequests: number,
  windowMs: number,
): { allowed: boolean; retryAfterSeconds: number } => {
  const now = Date.now();
  const existing = rateBuckets.get(key);

  if (!existing || existing.resetAt <= now) {
    rateBuckets.set(key, { count: 1, resetAt: now + windowMs });
    return { allowed: true, retryAfterSeconds: 0 };
  }

  if (existing.count >= maxRequests) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((existing.resetAt - now) / 1000)),
    };
  }

  existing.count += 1;
  return { allowed: true, retryAfterSeconds: 0 };
};

export const requireAiUser = async (
  req: any,
  res: any,
  options: ApiSecurityOptions = {},
): Promise<User | null> => {
  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ message: 'Authentication required.' });
    return null;
  }

  try {
    const { url, anonKey } = getServerSupabaseConfig();
    const client = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: { user }, error } = await client.auth.getUser(token);
    if (error || !user) {
      res.status(401).json({ message: 'Invalid or expired session.' });
      return null;
    }

    if (options.allowedRoles?.length) {
      const { data: roleData, error: roleError } = await client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

      if (roleError || !roleData || !options.allowedRoles.includes(roleData.role)) {
        res.status(403).json({ message: 'You do not have access to this AI feature.' });
        return null;
      }
    }

    const maxRequests = options.maxRequests ?? 20;
    const windowMs = options.windowMs ?? 10 * 60 * 1000;
    const rate = consumeRateLimit(user.id, maxRequests, windowMs);

    if (!rate.allowed) {
      res.setHeader('Retry-After', String(rate.retryAfterSeconds));
      res.status(429).json({ message: 'Too many AI requests. Please try again later.' });
      return null;
    }

    return user;
  } catch (error) {
    console.error('AI authentication boundary failed:', error);
    res.status(503).json({ message: 'Authentication service is temporarily unavailable.' });
    return null;
  }
};

export const getGeminiApiKey = (): string => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error('AI service is not configured.');
  return apiKey;
};

export const validateText = (
  value: unknown,
  fieldName: string,
  maxLength: number,
): string => {
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${fieldName} is required.`);
  }
  if (value.length > maxLength) {
    throw new Error(`${fieldName} exceeds the allowed length.`);
  }
  return value.trim();
};

export const validateInlineFile = (
  fileData: unknown,
  mimeType: unknown,
  options: { maxBytes?: number; allowedMimeTypes?: string[] } = {},
): { fileData: string; mimeType: string } => {
  if (typeof fileData !== 'string' || typeof mimeType !== 'string') {
    throw new Error('File data and mimeType are required.');
  }

  const maxBytes = options.maxBytes ?? 3 * 1024 * 1024;
  const estimatedBytes = Math.floor((fileData.length * 3) / 4);

  if (estimatedBytes > maxBytes) {
    throw new Error('File is too large.');
  }

  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(fileData)) {
    throw new Error('File data is not valid base64.');
  }

  if (options.allowedMimeTypes?.length && !options.allowedMimeTypes.includes(mimeType)) {
    throw new Error('Unsupported file type.');
  }

  return { fileData, mimeType };
};

export const sendSafeApiError = (res: any, error: unknown, fallback: string) => {
  const message = error instanceof Error ? error.message : fallback;
  const isClientError = /required|exceeds|too large|unsupported|valid base64/i.test(message);

  if (!isClientError) {
    console.error(fallback, error);
  }

  return res.status(isClientError ? 400 : 500).json({
    message: isClientError ? message : fallback,
  });
};
