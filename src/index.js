/**
 * AWS Lambda handler.
 *
 * @param {object} event   - The event payload (e.g. API Gateway proxy request).
 * @param {object} context - The Lambda runtime context.
 * @returns {Promise<object>} An API Gateway-compatible HTTP response.
 */
exports.handler = async (event, context) => {
  console.log("Received event:", JSON.stringify(event));

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: "Hello from lambda-learn-backend!",
    }),
  };
};
