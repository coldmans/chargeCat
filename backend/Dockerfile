# syntax=docker/dockerfile:1.6

# Azure Container Apps / App Service(컨테이너) / 일반 VM 어디에서도 동작하도록
# 정석적인 multi-stage 구성. 런타임은 node:25-bookworm-slim 최소 이미지.

ARG NODE_IMAGE=node:25-bookworm-slim

# ---------- deps ----------
FROM ${NODE_IMAGE} AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---------- runtime ----------
FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
    PORT=8787

WORKDIR /app

# 비루트 실행자(node 유저는 node:slim 이미지에 이미 존재)
COPY --chown=node:node --from=deps /app/node_modules ./node_modules
COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node src ./src
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node docker ./docker
COPY --chown=node:node assets ./assets

USER node

EXPOSE 8787

# 헬스체크는 플랫폼(App Service/Container Apps) probe에 맡기는 편이 운영상 유연하다.
# 컨테이너 단독 실행을 편하게 하려면 아래 주석을 해제.
# HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
#   CMD node -e "fetch('http://127.0.0.1:'+process.env.PORT+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/app.js"]
