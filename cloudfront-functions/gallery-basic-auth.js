function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var expected = 'Basic ${auth_credentials}';

    if (!headers.authorization || headers.authorization.value !== expected) {
        return {
            statusCode: 401,
            statusDescription: 'Unauthorized',
            headers: {
                'www-authenticate': { value: 'Basic realm="Vitrai Gallery"' },
                'content-type': { value: 'text/html; charset=utf-8' },
                'cache-control': { value: 'no-store' },
                // Any 401 (i.e. logging out) makes the browser drop everything
                // it cached from this origin, so stale app files can't survive
                // a logout/login cycle
                'clear-site-data': { value: '"cache"' }
            },
            body: '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
                + '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
                + '<title>Gallery &mdash; Signed out</title>'
                + '<style>'
                + 'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;'
                + 'background:#f9fafb;display:flex;align-items:center;justify-content:center;'
                + 'height:100vh;margin:0}'
                + '.card{text-align:center;background:#fff;padding:2.5rem 3rem;border-radius:8px;'
                + 'box-shadow:0 1px 3px rgba(0,0,0,.1),0 1px 2px rgba(0,0,0,.06)}'
                + 'h1{font-size:1.25rem;color:#1f2937;margin:0 0 .5rem}'
                + 'p{color:#6b7280;font-size:.9rem;margin:0 0 1.5rem}'
                + 'a{display:inline-block;background:#2563eb;color:#fff;text-decoration:none;'
                + 'padding:.5rem 1.25rem;border-radius:6px;font-size:.9rem}'
                + '</style></head><body><div class="card">'
                + '<h1>Signed out</h1>'
                + '<p>You are not signed in to the gallery.</p>'
                + '<a href="/">Sign in</a>'
                + '</div></body></html>'
        };
    }

    return request;
}
