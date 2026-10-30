import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

/** Where account photos live: a private, S3-compatible bucket (#142). */
export interface AvatarStorage {
  put(key: string, bytes: Uint8Array, contentType: string): Promise<void>;
  delete(key: string): Promise<void>;
  /** A temporary link to read the object, for the logged-in app. */
  signedUrl(key: string): Promise<string>;
}

export type StorageEnv = {
  AWS_ENDPOINT_URL_S3?: string | undefined;
  AWS_ACCESS_KEY_ID?: string | undefined;
  AWS_SECRET_ACCESS_KEY?: string | undefined;
  AWS_REGION?: string | undefined;
  S3_BUCKET?: string | undefined;
};

const LINK_SECONDS = 6 * 60 * 60;

/** The bucket from the environment, or undefined when a variable is missing (uploads then answer 503). */
export function s3Storage(env: StorageEnv): AvatarStorage | undefined {
  const { AWS_ENDPOINT_URL_S3, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET } = env;
  if (!AWS_ENDPOINT_URL_S3 || !AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY || !S3_BUCKET) {
    return undefined;
  }
  const client = new S3Client({
    endpoint: AWS_ENDPOINT_URL_S3,
    region: env.AWS_REGION || "auto",
    // `<endpoint>/<bucket>/<key>`: S3-compatible stores (Neon) sign one wildcard level under the endpoint, so the
    // AWS default `<bucket>.<endpoint>` fails the TLS check (#153).
    forcePathStyle: true,
    credentials: { accessKeyId: AWS_ACCESS_KEY_ID, secretAccessKey: AWS_SECRET_ACCESS_KEY },
  });
  const Bucket = S3_BUCKET;
  return {
    async put(key, bytes, contentType) {
      await client.send(
        new PutObjectCommand({ Bucket, Key: key, Body: bytes, ContentType: contentType }),
      );
    },
    async delete(key) {
      await client.send(new DeleteObjectCommand({ Bucket, Key: key }));
    },
    signedUrl(key) {
      return getSignedUrl(client, new GetObjectCommand({ Bucket, Key: key }), {
        expiresIn: LINK_SECONDS,
      });
    },
  };
}
