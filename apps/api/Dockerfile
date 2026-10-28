# syntax=docker/dockerfile:1
# Build from the repo root: docker build -f apps/api/Dockerfile -t hts-api .

FROM node:24-alpine AS base
ENV PNPM_HOME=/pnpm PATH=/pnpm:$PATH
RUN corepack enable
WORKDIR /repo

FROM base AS build
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json tsconfig.base.json ./
COPY apps/api/package.json apps/api/
# The root package depends on workspace packages; their manifests are enough to resolve the workspace.
COPY packages/design-tokens/package.json packages/design-tokens/
COPY packages/progression/package.json packages/progression/
COPY packages/contracts/package.json packages/contracts/
COPY packages/fixtures/package.json packages/fixtures/
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile --filter api...
COPY apps/api apps/api
RUN pnpm --filter api build \
  && pnpm --filter api deploy --legacy --prod /out \
  && cp -r apps/api/dist apps/api/drizzle /out/

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /out ./
USER node
# The platform (Render) injects PORT; the app reads it from the environment.
ENV PORT=8080
EXPOSE 8080
# Migrations first, then the server: a failed migration stops the deploy instead of serving an old schema.
CMD ["sh", "-c", "node dist/migrate-main.js && exec node dist/index.js"]
