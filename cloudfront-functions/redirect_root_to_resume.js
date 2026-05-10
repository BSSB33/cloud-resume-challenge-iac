function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;

    if (host === 'vitraigabor.eu') {
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                location: { value: 'https://resume.vitraigabor.eu' + request.uri }
            }
        };
    }

    return request;
}
