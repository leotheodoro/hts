# syntax=docker/dockerfile:1
# Build from the repo root: docker build -f apps/api/Dockerfile -t hts-api .

FROM node:24-alpine AS base
ENV PNPM_HOME=/pnpm PATH=/pnpm:$PATH
RUN corepack enable
WORKDIR /repo

FROM base AS build
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json tsconfig.base.json ./
COPY apps/api/package.json apps/api/
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
# Cloud Run injects PORT; the app reads it from the environment.
ENV PORT=8080
EXPOSE 8080
CMD ["node", "dist/index.js"]
