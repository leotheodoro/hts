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
    this.prune();
    for (const key of keys) this.failures.set(key, [...this.recent(key), this.now()]);
  }

  /** Keys with failures still inside the window. */
  get size(): number {
    return this.failures.size;
  }

  /** Drops keys whose failures all left the window, so random identifiers cannot grow the map. */
  private prune(): void {
    for (const key of [...this.failures.keys()]) {
      if (this.recent(key).length === 0) this.failures.delete(key);
    }
  }

  reset(key: string): void {
    this.failures.delete(key);
  }

  private recent(key: string): number[] {
    const since = this.now() - this.windowMs;
    return (this.failures.get(key) ?? []).filter((at) => at > since);
  }
}

/** Runs at most `max` tasks at once; the rest wait in order. Bounds the argon2 memory under a flood. */
export class ConcurrencyLimit {
  private running = 0;
  private waiting: (() => void)[] = [];

  constructor(private readonly max: number) {}

  async run<T>(task: () => Promise<T>): Promise<T> {
    if (this.running >= this.max) await new Promise<void>((resolve) => this.waiting.push(resolve));
    this.running++;
    try {
      return await task();
    } finally {
      this.running--;
      this.waiting.shift()?.();
    }
  }
}
