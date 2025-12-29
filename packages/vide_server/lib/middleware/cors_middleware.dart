import 'package:shelf/shelf.dart';

/// CORS middleware for REST API
///
/// Allows requests from any origin for local development.
/// Production deployments should restrict origins appropriately.
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Handle preflight requests
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }

      // Process request and add CORS headers to response
      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

/// CORS headers for all responses
const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
  'Access-Control-Max-Age': '86400', // 24 hours
};
