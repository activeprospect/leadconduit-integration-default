const _ = require('lodash');
const { assert } = require('chai');
const url = require('url');
const querystring = require('querystring');
const integration = require('../lib/inbound');


describe('Inbound Request', function() {

  it('should not allow head', () => assertMethodNotAllowed('head'));


  it('should not allow put', () => assertMethodNotAllowed('put'));


  it('should not allow delete', () => assertMethodNotAllowed('delete'));


  it('should not allow patch', () => assertMethodNotAllowed('patch'));


  it('should require content type header for posts with content', () => {
    try {
      integration.request({method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': '1' }});
      assert.fail("expected an error to be thrown when no content type is specified");
    } catch (e) {
      assert.equal(e.status, 415);
      assert.equal(e.body, 'Content-Type header is required');
      assert.deepEqual(e.headers, {'Content-Type': 'text/plain'});
    }
  });


  it('should require supported mimetype', () => {
    try {
      integration.request({method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': '1', 'Content-Type': 'Monkies' }});
      assert.fail("expected an error to be thrown when no content type is specified");
    } catch (e) {
      assert.equal(e.status, 406);
      assert.equal(e.body, 'MIME type in Content-Type header is not supported. Use only application/x-www-form-urlencoded, application/json, application/xml, text/xml.');
      assert.deepEqual(e.headers, {'Content-Type': 'text/plain'});
    }
  });


  it('should throw an error when it cant parse xml', () => {
    const body = 'xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken';
    try {
      integration.request({method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': body.length, 'Content-Type': 'application/xml'}, body});
      assert.fail("expected an error to be thrown when xml content cannot be parsed");
    } catch (e) {
      assert.equal(e.status, 400);
      assert.equal(e.body, 'Body does not contain XML or XML is unparseable -- Error: Non-whitespace before first tag. Line: 0 Column: 1 Char: x.');
      assert.deepEqual(e.headers, {'Content-Type': 'text/plain'});
    }
  });

  it('should throw an error when it cant parse form-encoded data', () => {
    const body = 'first_name=SolarReviews&&postal_code=92014&utility=SCE&price=98&utility.electric.company.name=SCE&electric_monthly_amount_oos=150&email=Test@solarreviews123.com';
    try {
      integration.request({method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': body.length, 'Content-Type': 'application/x-www-form-urlencoded'}, body});
      assert.fail("expected an error to be thrown when form-encoded content cannot be parsed");
    } catch (e) {
      assert.equal(e.status, 400);
      assert.equal(e.body, "Unable to parse body -- TypeError: Cannot read property 'company' of undefined.");
      assert.deepEqual(e.headers, {'Content-Type': 'text/plain'});
    }
  });


  it('should not parse empty body', () => {
      const req = {
        method: 'POST',
        uri: '/flows/12345/sources/12345/submit?first_name=Joe&last_name=Blow&phone_1=5127891111',
        headers: {
          'Content-Length': 152,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: ''
      };
      const result = integration.request(req);
      assert.deepEqual(result, {first_name: 'Joe', last_name: 'Blow', phone_1: '5127891111'});
   });


  it('should parse posted form url encoded body', () => {
    const body = 'first_name=Joe&last_name=Blow&email=jblow@test.com&phone_1=5127891111';
    assertParses('application/x-www-form-urlencoded', body);
  });


  it('should parse nested form url encoded body', () => {
    const body = 'first_name=Joe&callcenter.additional_services=script+writing';
    assertParses('application/x-www-form-urlencoded', body, {
      first_name: 'Joe',
      callcenter: {
        additional_services: 'script writing'
      }
    }
    );
  });


  it('should parse xxTrustedFormCertUrl from request body', () => {
    const body = 'xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken';
    assertParses('application/x-www-form-urlencoded', body, {trustedform_cert_url: 'https://cert.trustedform.com/testtoken'});
  });


  it('should parse xxTrustedFormCertUrl case insensitively', () => {
    const body = 'XXTRUSTEDFORMCERTURL=https://cert.trustedform.com/testtoken';
    assertParses('application/x-www-form-urlencoded', body, {trustedform_cert_url: 'https://cert.trustedform.com/testtoken'});
  });


  it('should parse query string on POST', () => {
    const body = 'param1=val1';
    const req = {
      method: 'POST',
      uri: '/flows/12345/sources/12345/submit?first_name=Joe&last_name=Blow&phone_1=5127891111',
      headers: {
        'Content-Length': body.length,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body
    };
    const result = integration.request(req);
    assert.deepEqual(result, {first_name: 'Joe', last_name: 'Blow', phone_1: '5127891111', param1: 'val1'});
  });


  it('should return 400 on invalid redir_url', () => {
    const req = {
      method: 'POST',
      uri: '/flows/12345/sources/12345/submit?redir_url=scooby.doo',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    };
    try {
      integration.request(req);
      assert.fail(`expected ${method} to throw an error`);
    } catch (e) {
      assert.equal(e.status, 400);
      assert.equal(e.body, "Invalid redir_url");
    }
  });


  it('should not error on multiple redir_url values', () => {
    const req = {
      method: 'POST',
      uri: '/flows/12345/sources/12345/submit?redir_url=http://foo.com&first_name=Joe&redir_url=http://bar.com',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    };
    const result = integration.request(req);
    assert.equal(result.first_name, 'Joe');
  }); // just ensure request() finished without error


  it('should parse xxTrustedFormCertUrl from query string', () => {
    const req = {
      method: 'GET',
      uri: '/flows/12345/sources/12345/submit?xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken',
      headers: {}
    };
    const result = integration.request(req);
    assert.deepEqual(result, {trustedform_cert_url: 'https://cert.trustedform.com/testtoken'});
  });


  it('should parse posted json body', () => {
    const body = '{"first_name":"Joe","last_name":"Blow","email":"jblow@test.com","phone_1":"5127891111"}';
    assertParses('application/json', body);
  });


  it('should parse text xml', () => {
    const body = `\
<lead>
  <first_name>Joe</first_name>
  <last_name>Blow</last_name>
  <email>jblow@test.com</email>
  <phone_1>5127891111</phone_1>
</lead>\
`;

    assertParses('text/xml', body);
  });


  it('should parse posted application xml', () => {
    const body = `\
<lead>
  <first_name>Joe</first_name>
  <last_name>Blow</last_name>
  <email>jblow@test.com</email>
  <phone_1>5127891111</phone_1>
</lead>\
`;

    assertParses('application/xml', body);
  });
});



describe('Inbound Params', () =>

  it('should include wildcard', () =>
    assert(_.find(integration.request.params(), param => param.name === '*')
    )
  )
);



describe('Inbound examples', () => {

  it('should have uri', () => {
    const examples = integration.request.examples('123', '345', {});
    Array.from(_.map(examples, 'uri')).map((uri) =>
      assert.equal(url.parse(uri).href, '/flows/123/sources/345/submit'));
  });


  it('should have method', () => {
    const examples = integration.request.examples('123', '345', {});
    Array.from(_.map(examples, 'method')).map((method) =>
      assert((method === 'GET') || (method === 'POST')));
  });


  it('should have headers', () => {
    const examples = integration.request.examples('123', '345', {});
    for (let headers of Array.from(_.map(examples, 'headers'))) {
      assert(_.isPlainObject(headers));
      assert(headers['Accept']);
    }
});


  it('should include redir url in query string', () => {
    const redir = 'http://foo.com?bar=baz';
    const examples = integration.request.examples('123', '345', {redir_url: redir});
    for (let uri of Array.from(_.map(examples, 'uri'))) {
      const { query } = url.parse(uri, {query: true});
      assert.equal(query.redir_url, redir);
    }
  });


  it('should properly encode URL encoded request body', () => {
    const params = {
      first_name: 'alex',
      email: 'alex@test.com'
    };
    const examples = integration.request.examples('123', '345', params).filter(example => example.headers['Content-Type'] != null ? example.headers['Content-Type'].match(/urlencoded$/) : undefined);
    for (let example of Array.from(examples)) {
      assert.equal(example.body, querystring.encode(params));
    }
  });


  it('should properly encode XML request body', () => {
    const examples = integration.request.examples('123', '345', {first_name: 'alex', email: 'alex@test.com'}).filter(example => example.headers['Content-Type'] != null ? example.headers['Content-Type'].match(/xml$/) : undefined);
    for (let example of Array.from(examples)) {
      assert.equal(example.body, '<?xml version="1.0"?>\n<lead>\n  <first_name>alex</first_name>\n  <email>alex@test.com</email>\n</lead>');
    }
  });


  it('should properly encode JSON request body', () => {
    const examples = integration.request.examples('123', '345', {first_name: 'alex', email: 'alex@test.com'}).filter(example => example.headers['Content-Type'] != null ? example.headers['Content-Type'].match(/json$/) : undefined);
    for (let example of Array.from(examples)) {
      assert.equal(example.body, '{\n  "first_name": "alex",\n  "email": "alex@test.com"\n}');
    }
  });
});



describe('Inbound Response', () => {

  beforeEach(() => {
    this.vars = {
      lead: { id: '123' },
      outcome: 'failure',
      reason: 'bad!'
    };
  });


  it('should respond with json', () => {
    const res = integration.response(baseRequest('application/json'), this.vars);
    assert.equal(res.status, 201);
    assert.deepEqual(res.headers, {'Content-Type': 'application/json', 'Content-Length': 67});
    assert.equal(res.body, '{"outcome":"failure","reason":"bad!","lead":{"id":"123"},"price":0}');
  });


  it('should default to json', () => {
    const res = integration.response(baseRequest('*/*'), this.vars);
    assert.equal(res.status, 201);
    assert.deepEqual(res.headers['Content-Type'],  'application/json');
  });


  it('should respond with text xml', () => {
    const res = integration.response(baseRequest('text/xml'), this.vars);
    assert.equal(res.status, 201);
    assert.deepEqual(res.headers, {'Content-Type': 'text/xml', 'Content-Length': 148});
    assert.equal(res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n  <price>0</price>\n</result>');
  });


  it('should respond with application xml', () => {
    const res = integration.response(baseRequest(), this.vars);
    assert.equal(res.status, 201);
    assert.deepEqual(res.headers, {'Content-Type': 'application/xml', 'Content-Length': 148});
    assert.equal(res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n  <price>0</price>\n</result>');
  });


  it('should redirect', () => {
    const res = integration.response(baseRequest('application/xml', '?redir_url=http%3A%2F%2Ffoo%2Fbar%3Fbaz%3Dbip'), this.vars);
    assert.equal(res.status, 303);
    assert.equal(res.headers.Location, 'http://foo/bar?baz=bip');
  });


  it('should not error on multiple redir_urls', () => {
    const res = integration.response(baseRequest('application/xml', '?redir_url=http%3A%2F%2Ffoo%2Fbar%3Fbaz%3Dbip&something=else&redir_url=http%3A%2F%2Fshiny%2Fhappy%3Fpeople%3Dtrue'), this.vars);
    assert.equal(res.status, 303);
    assert.equal(res.headers.Location, 'http://foo/bar?baz=bip');
  });

  it('should capture price variable', () => {
    this.vars = { 
      outcome: 'success',
      price: 1.5,
      lead: { id: '123' }
    };
      
    const res = integration.response(baseRequest('application/json'), this.vars);
    assert.equal(res.status, 201);
    assert.deepEqual(res.headers, {'Content-Type': 'application/json', 'Content-Length': 53});
    assert.equal(res.body, '{"outcome":"success","lead":{"id":"123"},"price":1.5}');
  });

  describe('ping', () => {

    it('should not respond with lead id', () => {
      const req = baseRequest('application/json');
      req.uri = '/flows/123/sources/ping';
      // The LeadConduit handler omits the lead ID on ping requests
      delete this.vars.lead.id;
      this.vars.outcome = 'success';
      this.vars.reason = null;
      this.vars.price = 10;
      const res = integration.response(req, this.vars);
      assert.equal(res.status, 200);
      assert.deepEqual(res.headers, {'Content-Type': 'application/json', 'Content-Length':32});
      assert.equal(res.body, '{"outcome":"success","price":10}');
    });

    it('should respond with failure on $0 price', () => {
      const req = baseRequest('application/json');
      req.uri = '/flows/123/sources/ping';
      // The LeadConduit handler omits the lead ID on ping requests
      delete this.vars.lead.id;
      this.vars.outcome = 'success';
      this.vars.reason = null;
      this.vars.price = 0;
      const res = integration.response(req, this.vars);
      assert.equal(res.status, 200);
      assert.deepEqual(res.headers, {'Content-Type': 'application/json', 'Content-Length':49});
      assert.equal(res.body, '{"outcome":"failure","reason":"no bid","price":0}');
    });


    it('should not overwrite reason', () => {
      const req = baseRequest('application/json');
      req.uri = '/flows/123/sources/ping';
      // The LeadConduit handler omits the lead ID on ping requests
      delete this.vars.lead.id;
      this.vars.outcome = 'failure';
      this.vars.reason = 'terrible';
      this.vars.price = 0;
      const res = integration.response(req, this.vars);
      assert.equal(res.status, 200);
      assert.deepEqual(res.headers, {'Content-Type': 'application/json', 'Content-Length':51});
      assert.equal(res.body, '{"outcome":"failure","reason":"terrible","price":0}');
    });
  });


  describe('With specified fields in response', () => {

    beforeEach(() => {
      this.vars = {
        lead: { 
          id: '123',
          email: 'foo@bar.com'
        },
        outcome: 'failure',
        reason: 'bad!'
      };
    });

    it('should respond with json', () => {
      const res = integration.response(baseRequest('application/json'), this.vars, ['outcome', 'lead.id', 'lead.email', 'price']);
      assert.equal(res.status, 201);
      assert.equal(res.headers['Content-Type'], 'application/json');
      assert.equal(res.body, '{"outcome":"failure","lead":{"id":"123","email":"foo@bar.com"},"price":0}');
    });


    it('should respond with text xml', () => {
      const res = integration.response(baseRequest('text/xml'), this.vars, ['outcome', 'lead.id', 'lead.email', 'price']);
      assert.equal(res.status, 201);
      assert.equal(res.headers['Content-Type'], 'text/xml');
      assert.equal(res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <lead>\n    <id>123</id>\n    <email>foo@bar.com</email>\n  </lead>\n  <price>0</price>\n</result>');
    });

    it('should respond with application xml', () => {
      const res = integration.response(baseRequest(), this.vars, ['outcome', 'lead.id', 'lead.email', 'price']);
      assert.equal(res.status, 201);
      assert.equal(res.headers['Content-Type'], 'application/xml');
      assert.equal(res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <lead>\n    <id>123</id>\n    <email>foo@bar.com</email>\n  </lead>\n  <price>0</price>\n</result>');
    });
  });
});


var baseRequest = function(accept = null, querystring) {
  if (querystring == null) { querystring = ''; }
  return {
    uri: `/flows/123/sources/456/submit${querystring}`,
    method: 'post',
    version: '1.1',
    headers: {
      'Accept': accept != null ? accept : 'application/xml',
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: 'first_name=Joe',
    timestamp: new Date().getTime()
  };
};


var assertParses = function(contentType, body, expected) {
  const req = {
    method: 'POST',
    uri: '/flows/12345/sources/12345/submit',
    headers: {
      'Content-Length': body.length,
      'Content-Type': contentType
    },
    body
  };

  if (expected == null) { expected = {
    first_name: 'Joe',
    last_name: 'Blow',
    email: 'jblow@test.com',
    phone_1: '5127891111'
  }; }

  const result = integration.request(req);
  assert.deepEqual(result, expected);
};


var assertMethodNotAllowed = function(method) {
  try {
    integration.request({method});
    assert.fail(`expected ${method} to throw an error`);
  } catch (e) {
    assert.equal(e.status, 405);
    assert.equal(e.body, `The ${method.toUpperCase()} method is not allowed`);
    assert.deepEqual(e.headers, {
      'Allow': 'GET, POST',
      'Content-Type': 'text/plain'
    }
    );
  }
};
