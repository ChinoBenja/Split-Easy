import { createRemoteJWKSet, jwtVerify } from "jose";

const MODEL = "@cf/meta/llama-3.1-8b-instruct-fp8";
const MAX_MESSAGES = 12;
const MAX_MESSAGE_LENGTH = 2000;
const MAX_INPUT_LENGTH = 24000;
const MAX_OUTPUT_TOKENS = 768;
const RATE_LIMIT = 12;
const RATE_WINDOW_MS = 60_000;
const userRequests = new Map();
const firebaseSigningKeys = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const systemMessage = {
  role: "system",
  content: [
    "Eres el asistente de SplitEasy, una app para organizar gastos compartidos.",
    "Responde en español, de forma clara, amable y concisa.",
    "Ayuda a explicar cómo repartir cuentas y a usar una app de gastos compartidos.",
    "Puedes hacer cálculos solo con los datos que la persona escriba en el chat.",
    "No tienes acceso a grupos, gastos, perfiles ni datos de la app; no afirmes lo contrario.",
    "No solicites contraseñas, códigos de acceso ni datos de pago.",
    "Si falta información para un cálculo, pregunta lo necesario antes de asumir.",
  ].join(" "),
};

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": request.headers.get("Origin") ?? "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Max-Age": "86400",
      Vary: "Origin",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return jsonError(405, "method-not-allowed", corsHeaders);
    }

    const userId = await verifyFirebaseToken(request, env.FIREBASE_PROJECT_ID);
    if (!userId) {
      return jsonError(401, "unauthenticated", corsHeaders);
    }
    if (isRateLimited(userId)) {
      return jsonError(429, "resource-exhausted", corsHeaders);
    }

    try {
      const bodyText = await request.text();
      if (bodyText.length > 32_000) {
        return jsonError(413, "invalid-argument", corsHeaders);
      }

      let body;
      try {
        body = JSON.parse(bodyText);
      } catch {
        return jsonError(400, "invalid-argument", corsHeaders);
      }
      const messages = validateMessages(body?.messages);
      const result = await env.AI.run(MODEL, {
        messages: [systemMessage, ...messages],
        max_tokens: MAX_OUTPUT_TOKENS,
        temperature: 0.6,
      });

      if (typeof result?.response !== "string" || !result.response.trim()) {
        return jsonError(503, "unavailable", corsHeaders);
      }

      return Response.json(
        { reply: result.response.trim() },
        { headers: corsHeaders },
      );
    } catch (error) {
      if (error instanceof RequestValidationError) {
        return jsonError(error.status, error.code, corsHeaders);
      }
      return jsonError(503, "unavailable", corsHeaders);
    }
  },
};

async function verifyFirebaseToken(request, projectId) {
  if (!projectId) return null;
  const authorization = request.headers.get("Authorization");
  const match = authorization?.match(/^Bearer ([^\s]+)$/);
  if (!match) return null;

  try {
    const { payload } = await jwtVerify(match[1], firebaseSigningKeys, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    return typeof payload.sub === "string" && payload.sub.length > 0
      ? payload.sub
      : null;
  } catch {
    return null;
  }
}

function isRateLimited(userId) {
  const now = Date.now();
  for (const [id, window] of userRequests) {
    if (now - window.startedAt >= RATE_WINDOW_MS) userRequests.delete(id);
  }

  const window = userRequests.get(userId);
  if (!window || now - window.startedAt >= RATE_WINDOW_MS) {
    userRequests.set(userId, { startedAt: now, count: 1 });
    return false;
  }
  if (window.count >= RATE_LIMIT) return true;
  window.count += 1;
  return false;
}

function validateMessages(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_MESSAGES) {
    throw new RequestValidationError(400, "invalid-argument");
  }

  let totalLength = 0;
  const messages = value.map((message) => {
    if (
      message === null ||
      typeof message !== "object" ||
      !["user", "model"].includes(message.role) ||
      typeof message.text !== "string"
    ) {
      throw new RequestValidationError(400, "invalid-argument");
    }

    const text = message.text.trim();
    if (!text || text.length > MAX_MESSAGE_LENGTH) {
      throw new RequestValidationError(400, "invalid-argument");
    }
    totalLength += text.length;
    return { role: message.role, content: text };
  });

  if (
    totalLength > MAX_INPUT_LENGTH ||
    messages[messages.length - 1].role !== "user"
  ) {
    throw new RequestValidationError(400, "invalid-argument");
  }
  return messages;
}

function jsonError(status, code, headers = {}) {
  return Response.json({ error: { code } }, { status, headers });
}

class RequestValidationError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

export { isRateLimited, validateMessages, verifyFirebaseToken };
