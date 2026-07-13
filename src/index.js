'use strict';

/**
 * Greeting / main API Lambda.
 *
 * Handles direct invocations and Lambda Function URL / API Gateway events.
 * Shared helpers (CORS headers, JSON response builder, structured logging)
 * come from the "auth-utils" Lambda layer — see terraform/layer.tf.
 */

const { CORS_HEADERS, jsonResponse, log } = require('auth-utils');

const MAX_NAME_LENGTH = 64;

// Letters, digits, spaces and a few safe punctuation marks.
const NAME_PATTERN = /^[\p{L}\p{N} _.'-]+$/u;

/** Raised when request input fails validation; maps to HTTP 400. */
class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ValidationError';
  }
}

/**
 * Pulls the `name` argument from a Function URL event (query string)
 * or a direct invocation payload; defaults to "world".
 */
function extractName(event) {
  return (
    event?.queryStringParameters?.name ??
    event?.name ??
    'world'
  );
}

/**
 * Validates the requested name.
 * @param {*} name - The candidate name.
 * @throws {ValidationError} when the name is missing or malformed.
 * @returns {string} The validated name.
 */
function validateName(name) {
  if (typeof name !== 'string') {
    throw new ValidationError('"name" must be a string');
  }
  if (name.length > MAX_NAME_LENGTH) {
    throw new ValidationError(`"name" must be at most ${MAX_NAME_LENGTH} characters`);
  }
  if (!NAME_PATTERN.test(name)) {
    throw new ValidationError('"name" contains invalid characters');
  }
  return name;
}

/**
 * Builds the response payload. Pure function — easy to unit test.
 * @param {object} event - The Lambda invocation event.
 * @returns {object} The response body object.
 */
function buildPayload(event) {
  const name = validateName(extractName(event));

  return {
    message: `Hello, ${name}!`,
    stage: process.env.STAGE ?? 'unknown',
    timestamp: new Date().toISOString(),
    requestId: event?.requestContext?.requestId ?? null,
  };
}

/**
 * Lambda entry point.
 */
exports.handler = async (event) => {
  const method = event?.requestContext?.http?.method ?? 'GET';

  // Answer CORS preflight requests without running the handler logic.
  if (method === 'OPTIONS') {
    return { statusCode: 204, headers: CORS_HEADERS, body: '' };
  }

  try {
    const payload = buildPayload(event);
    log('info', 'request handled', { requestId: payload.requestId });
    return jsonResponse(200, payload);
  } catch (err) {
    if (err instanceof ValidationError) {
      log('warn', 'validation failed', { error: err.message });
      return jsonResponse(400, { error: err.message });
    }
    log('error', 'unhandled error', { error: String(err) });
    return jsonResponse(500, { error: 'Internal Server Error' });
  }
};

exports.buildPayload = buildPayload;
exports.validateName = validateName;
exports.ValidationError = ValidationError;
