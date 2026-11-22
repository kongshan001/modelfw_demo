export type ProviderErrorCode =
  | "missing_key"
  | "rate_limited"
  | "upstream_error"
  | "invalid_response";

export class ProviderError extends Error {
  readonly code: ProviderErrorCode;
  readonly status: number | null;
  readonly hint: string | null;

  constructor(
    message: string,
    options: {
      code: ProviderErrorCode;
      status?: number | null;
      hint?: string | null;
      cause?: unknown;
    }
  ) {
    super(message, { cause: options.cause });
    this.name = "ProviderError";
    this.code = options.code;
    this.status = options.status ?? null;
    this.hint = options.hint ?? null;
  }
}

const DEFAULT_TIMEOUT_MS = 15_000;

/**
 * Fetches and parses JSON without ever echoing request headers, credentials or
 * response bodies into errors. These errors are shown directly to the user.
 */
export async function fetchJson(
  url: string,
  init: RequestInit,
  timeoutMs = DEFAULT_TIMEOUT_MS
): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...init,
      cache: "no-store",
      signal: controller.signal
    });

    if (!response.ok) {
      const code =
        response.status === 429
          ? "rate_limited"
          : response.status === 401 || response.status === 403
            ? "missing_key"
            : "upstream_error";
      throw new ProviderError(
        code === "rate_limited"
          ? "搜索服务返回限流（HTTP 429），请稍后再试"
          : code === "missing_key"
            ? `搜索服务拒绝了凭证（HTTP ${response.status}），请检查 API key`
            : `搜索服务请求失败（HTTP ${response.status}）`,
        {
          code,
          status: response.status,
          hint:
            code === "rate_limited"
              ? "免费额度或速率限制可能已用尽，请查看服务商后台。"
              : code === "missing_key"
                ? "请确认 key 有效、账户有余额，并已开启对应 API。"
                : "可稍后重试，或在 .env.local 切换 SEARCH_PROVIDER=mock。"
        }
      );
    }

    try {
      return (await response.json()) as unknown;
    } catch (error) {
      throw new ProviderError("搜索服务返回了无法解析的 JSON", {
        code: "invalid_response",
        cause: error
      });
    }
  } catch (error) {
    if (error instanceof ProviderError) throw error;
    if (error instanceof Error && error.name === "AbortError") {
      throw new ProviderError("搜索服务请求超时", {
        code: "upstream_error",
        hint: "请稍后重试，或检查网络与搜索服务状态。"
      });
    }
    throw new ProviderError("无法连接搜索服务", {
      code: "upstream_error",
      hint: "请检查网络连接；本地演示可设置 SEARCH_PROVIDER=mock。",
      cause: error
    });
  } finally {
    clearTimeout(timeout);
  }
}
