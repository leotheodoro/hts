/**
 * Failed login attempts per key (IP and identifier), in memory: the API runs as one instance.
 * A key with `limit` failures inside the window is blocked until the oldest one leaves it.
 */
export class LoginLimiter {
  private failures = new Map<string, number[]>();

  constructor(
    private readonly limit = 10,
    private readonly windowMs = 15 * 60 * 1000,
    private readonly now: () => number = Date.now,
  ) {}

  isBlocked(keys: string[]): boolean {
    return keys.some((key) => this.recent(key).length >= this.limit);
  }

  recordFailure(keys: string[]): void {
    for (const key of keys) this.failures.set(key, [...this.recent(key), this.now()]);
  }

  reset(key: string): void {
    this.failures.delete(key);
  }

  private recent(key: string): number[] {
    const since = this.now() - this.windowMs;
    return (this.failures.get(key) ?? []).filter((at) => at > since);
  }
}
