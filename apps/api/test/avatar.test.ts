import { inArray } from "drizzle-orm";
import { afterAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import { athlete } from "../src/db/schema.js";
import { type AvatarStorage, s3Storage } from "../src/storage.js";
import { bearer, createTestAccount, createTestDb, removeAccounts } from "./db.js";

/** The bucket in memory: keys and what was deleted. */
class FakeStorage implements AvatarStorage {
  objects = new Map<string, { bytes: Uint8Array; contentType: string }>();
  deleted: string[] = [];
  async put(key: string, bytes: Uint8Array, contentType: string) {
    this.objects.set(key, { bytes, contentType });
  }
  async delete(key: string) {
    this.deleted.push(key);
    this.objects.delete(key);
  }
  async signedUrl(key: string) {
    return `https://bucket.test/${key}?signature=x`;
  }
}

const { db, close } = createTestDb();
const athletes: string[] = [];

afterAll(async () => {
  await removeAccounts(db, athletes);
  if (athletes.length > 0) await db.delete(athlete).where(inArray(athlete.id, athletes));
  await close();
});

async function account() {
  const created = await createTestAccount(db);
  athletes.push(created.athleteId);
  return created;
}

const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const upload = (
  target: ReturnType<typeof createApp>,
  token: string,
  body: Uint8Array,
  type = "image/jpeg",
) =>
  target.request("/v1/account/avatar", {
    method: "PUT",
    headers: { ...bearer(token), "content-type": type },
    body,
  });

type Me = { account: { avatarUrl: string | null } };

describe("PUT /v1/account/avatar", () => {
  it("stores the photo in the bucket and answers a signed link", async () => {
    const storage = new FakeStorage();
    const app = createApp({ db, storage });
    const leo = await account();
    const res = await upload(app, leo.token, jpeg);
    expect(res.status).toBe(200);
    const { account: first } = (await res.json()) as Me;
    expect(first.avatarUrl).toMatch(
      new RegExp(`^https://bucket.test/avatars/${leo.accountId}/[0-9a-f-]+\\.jpg\\?signature=x$`),
    );
    expect([...storage.objects.values()][0]?.contentType).toBe("image/jpeg");

    const me = (await (
      await app.request("/v1/auth/me", { headers: bearer(leo.token) })
    ).json()) as Me;
    expect(me.account.avatarUrl).toBe(first.avatarUrl);

    const { account: second } = (await (await upload(app, leo.token, jpeg)).json()) as Me;
    expect(second.avatarUrl).not.toBe(first.avatarUrl);
    expect(storage.deleted).toHaveLength(1);
    expect(storage.objects.size).toBe(1);
  });

  it("refuses what is not a JPEG or is too big", async () => {
    const app = createApp({ db, storage: new FakeStorage() });
    const leo = await account();
    expect((await upload(app, leo.token, jpeg, "image/gif")).status).toBe(400);
    expect((await upload(app, leo.token, new Uint8Array([1, 2, 3]))).status).toBe(400);
    const big = new Uint8Array(2 * 1024 * 1024 + 1);
    big.set(jpeg);
    expect((await upload(app, leo.token, big)).status).toBe(413);
  });

  it("answers 503 when the bucket is not configured", async () => {
    const app = createApp({ db });
    const leo = await account();
    const res = await upload(app, leo.token, jpeg);
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "storage_unavailable" });
  });
});

describe("s3Storage", () => {
  it("is off unless every variable is set", () => {
    const full = {
      AWS_ENDPOINT_URL_S3: "https://s3.example.com",
      AWS_ACCESS_KEY_ID: "id",
      AWS_SECRET_ACCESS_KEY: "secret",
      S3_BUCKET: "photos",
    };
    expect(s3Storage(full)).toBeDefined();
    expect(s3Storage({ ...full, S3_BUCKET: undefined })).toBeUndefined();
  });
});
