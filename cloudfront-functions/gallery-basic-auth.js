function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var expected = 'Basic ${auth_credentials}';

    if (!headers.authorization || headers.authorization.value !== expected) {
        return {
            statusCode: 401,
            statusDescription: 'Unauthorized',
            headers: {
                'www-authenticate': { value: 'Basic realm="Vitrai Gallery"' }
            },
            body: 'Unauthorized'
        };
    }

    return request;
}
