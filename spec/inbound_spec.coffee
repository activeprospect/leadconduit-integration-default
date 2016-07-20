_ = require('lodash')
assert = require('chai').assert
url = require('url')
querystring = require('querystring')
integration = require('../src/inbound')


describe 'Inbound Request', ->

  it 'should not allow head', ->
    assertMethodNotAllowed('head')


  it 'should not allow put', ->
    assertMethodNotAllowed('put')


  it 'should not allow delete', ->
    assertMethodNotAllowed('delete')


  it 'should not allow patch', ->
    assertMethodNotAllowed('patch')


  it 'should require content type header for posts with content', ->
    try
      integration.request(method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': '1' })
      assert.fail("expected an error to be thrown when no content type is specified")
    catch e
      assert.equal e.status, 415
      assert.equal e.body, 'Content-Type header is required'
      assert.deepEqual e.headers, 'Content-Type': 'text/plain'


  it 'should require supported mimetype', ->
    try
      integration.request(method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': '1', 'Content-Type': 'Monkies' })
      assert.fail("expected an error to be thrown when no content type is specified")
    catch e
      assert.equal e.status, 406
      assert.equal e.body, 'MIME type in Content-Type header is not supported. Use only application/x-www-form-urlencoded, application/json, application/xml, text/xml.'
      assert.deepEqual e.headers, 'Content-Type': 'text/plain'


  it 'should throw an error when it cant parse xml', ->
    body = 'xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken'
    try
      integration.request(method: 'post', uri: '/flows/12345/sources/12345/submit', headers: { 'Content-Length': body.length, 'Content-Type': 'application/xml'}, body: body)
      assert.fail("expected an error to be thrown when xml content cannot be parsed")
    catch e
      assert.equal e.status, 400
      assert.equal e.body, 'Body does not contain XML or XML is unparseable -- Error: Non-whitespace before first tag. Line: 0 Column: 1 Char: x.'
      assert.deepEqual e.headers, 'Content-Type': 'text/plain'


   it 'should not parse empty body', ->
      req =
        method: 'POST'
        uri: '/flows/12345/sources/12345/submit?first_name=Joe&last_name=Blow&phone_1=5127891111'
        headers: {
          'Content-Length': 152
          'Content-Type': 'application/x-www-form-urlencoded'
        }
        body: ''
      result = integration.request(req)
      assert.deepEqual result, first_name: 'Joe', last_name: 'Blow', phone_1: '5127891111'


  it 'should parse posted form url encoded body', ->
    body = 'first_name=Joe&last_name=Blow&email=jblow@test.com&phone_1=5127891111'
    assertParses 'application/x-www-form-urlencoded', body


  it 'should parse nested form url encoded body', ->
    body = 'first_name=Joe&callcenter.additional_services=script+writing'
    assertParses 'application/x-www-form-urlencoded', body,
      first_name: 'Joe'
      callcenter:
        additional_services: 'script writing'


  it 'should parse xxTrustedFormCertUrl from request body', ->
    body = 'xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken'
    assertParses 'application/x-www-form-urlencoded', body, trustedform_cert_url: 'https://cert.trustedform.com/testtoken'


  it 'should parse xxTrustedFormCertUrl case insensitively', ->
    body = 'XXTRUSTEDFORMCERTURL=https://cert.trustedform.com/testtoken'
    assertParses 'application/x-www-form-urlencoded', body, trustedform_cert_url: 'https://cert.trustedform.com/testtoken'


  it 'should parse query string on POST', ->
    body = 'param1=val1'
    req =
      method: 'POST'
      uri: '/flows/12345/sources/12345/submit?first_name=Joe&last_name=Blow&phone_1=5127891111'
      headers: {
        'Content-Length': body.length
        'Content-Type': 'application/x-www-form-urlencoded'
      }
      body: body
    result = integration.request(req)
    assert.deepEqual result, first_name: 'Joe', last_name: 'Blow', phone_1: '5127891111', param1: 'val1'


  it 'should parse xxTrustedFormCertUrl from query string', ->
    req =
      method: 'GET'
      uri: '/flows/12345/sources/12345/submit?xxTrustedFormCertUrl=https://cert.trustedform.com/testtoken'
      headers: {}
    result = integration.request(req)
    assert.deepEqual result, trustedform_cert_url: 'https://cert.trustedform.com/testtoken'


  it 'should parse posted json body', ->
    body = '{"first_name":"Joe","last_name":"Blow","email":"jblow@test.com","phone_1":"5127891111"}'
    assertParses 'application/json', body


  it 'should parse text xml', ->
    body = '''
           <lead>
             <first_name>Joe</first_name>
             <last_name>Blow</last_name>
             <email>jblow@test.com</email>
             <phone_1>5127891111</phone_1>
           </lead>
           '''

    assertParses 'text/xml', body


  it 'should parse posted application xml', ->
    body = '''
           <lead>
             <first_name>Joe</first_name>
             <last_name>Blow</last_name>
             <email>jblow@test.com</email>
             <phone_1>5127891111</phone_1>
           </lead>
           '''

    assertParses 'application/xml', body



describe 'Inbound Params', ->

  it 'should include wildcard', ->
    assert _.find integration.request.params(), (param) ->
      param.name == '*'



describe 'Inbound examples', ->

  it 'should have uri', ->
    examples = integration.request.examples('123', '345', {})
    for uri in _.pluck(examples, 'uri')
      assert.equal url.parse(uri).href, '/flows/123/sources/345/submit'


  it 'should have method', ->
    examples = integration.request.examples('123', '345', {})
    for method in _.pluck(examples, 'method')
      assert method == 'GET' or method == 'POST'


  it 'should have headers', ->
    examples = integration.request.examples('123', '345', {})
    for headers in _.pluck(examples, 'headers')
      assert _.isPlainObject(headers)
      assert headers['Accept']


  it 'should include redir url in query string', ->
    redir = 'http://foo.com?bar=baz'
    examples = integration.request.examples('123', '345', redir_url: redir)
    for uri in _.pluck(examples, 'uri')
      query = url.parse(uri, query: true).query
      assert.equal query.redir_url, redir


  it 'should properly encode URL encoded request body', ->
    params =
      first_name: 'alex'
      email: 'alex@test.com'
    examples = integration.request.examples('123', '345', params).filter (example) ->
      example.headers['Content-Type']?.match(/urlencoded$/)
    for example in examples
      assert.equal example.body, querystring.encode(params)


  it 'should properly encode XML request body', ->
    examples = integration.request.examples('123', '345', first_name: 'alex', email: 'alex@test.com').filter (example) ->
      example.headers['Content-Type']?.match(/xml$/)
    for example in examples
      assert.equal example.body, '<?xml version="1.0"?>\n<lead>\n  <first_name>alex</first_name>\n  <email>alex@test.com</email>\n</lead>'


  it 'should properly encode JSON request body', ->
    examples = integration.request.examples('123', '345', first_name: 'alex', email: 'alex@test.com').filter (example) ->
      example.headers['Content-Type']?.match(/json$/)
    for example in examples
      assert.equal example.body, '{\n  "first_name": "alex",\n  "email": "alex@test.com"\n}'



describe 'Inbound Response', ->

  vars =
    lead: { id: '123' }
    outcome: 'failure'
    reason: 'bad!'

  it 'should respond with json', ->
    res = integration.response(baseRequest('application/json'), vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'application/json', 'Content-Length': 57
    assert.equal res.body, '{"outcome":"failure","reason":"bad!","lead":{"id":"123"}}'


  it 'should default to json', ->
    res = integration.response(baseRequest('*/*'), vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers['Content-Type'],  'application/json'


  it 'should respond with text xml', ->
    res = integration.response(baseRequest('text/xml'), vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'text/xml', 'Content-Length': 129
    assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n</result>'


  it 'should respond with application xml', ->
    res = integration.response(baseRequest(), vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'application/xml', 'Content-Length': 129
    assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n</result>'


  it 'should redirect', ->
    res = integration.response(baseRequest('application/xml', '?redir_url=http%3A%2F%2Ffoo%2Fbar%3Fbaz%3Dbip'), vars)
    assert.equal res.status, 303
    assert.equal res.headers.Location, 'http://foo/bar?baz=bip'


  it 'should not error on multiple redir_urls', ->
    res = integration.response(baseRequest('application/xml', '?redir_url=http%3A%2F%2Ffoo%2Fbar%3Fbaz%3Dbip&something=else&redir_url=http%3A%2F%2Fshiny%2Fhappy%3Fpeople%3Dtrue'), vars)
    assert.equal res.status, 303
    assert.equal res.headers.Location, 'http://foo/bar?baz=bip'


  describe 'With specified fields in response', ->

    vars =
      lead:
        id: '123'
        email: 'foo@bar.com'
      outcome: 'failure'
      reason: 'bad!'

    it 'should respond with json', ->
      res = integration.response(baseRequest('application/json'), vars, ['outcome', 'lead.id', 'lead.email'])
      assert.equal res.status, 201
      assert.equal res.headers['Content-Type'], 'application/json'
      assert.equal res.body, '{"outcome":"failure","lead":{"id":"123","email":"foo@bar.com"}}'


    it 'should respond with text xml', ->
      res = integration.response(baseRequest('text/xml'), vars, ['outcome', 'lead.id', 'lead.email'])
      assert.equal res.status, 201
      assert.equal res.headers['Content-Type'], 'text/xml'
      assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <lead>\n    <id>123</id>\n    <email>foo@bar.com</email>\n  </lead>\n</result>'

    it 'should respond with application xml', ->
      res = integration.response(baseRequest(), vars, ['outcome', 'lead.id', 'lead.email'])
      assert.equal res.status, 201
      assert.equal res.headers['Content-Type'], 'application/xml'
      assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <lead>\n    <id>123</id>\n    <email>foo@bar.com</email>\n  </lead>\n</result>'


baseRequest = (accept = null, querystring = '') ->
  uri: "/whatever#{querystring}"
  method: 'post'
  version: '1.1'
  headers:
    'Accept': accept ? 'application/xml'
    'Content-Type': 'application/x-www-form-urlencoded'
  body: 'first_name=Joe'
  timestamp: new Date().getTime()


assertParses = (contentType, body, expected) ->
  req =
    method: 'POST'
    uri: '/flows/12345/sources/12345/submit'
    headers:
      'Content-Length': body.length
      'Content-Type': contentType
    body: body

  expected ?=
    first_name: 'Joe'
    last_name: 'Blow'
    email: 'jblow@test.com'
    phone_1: '5127891111'

  result = integration.request(req)
  assert.deepEqual result, expected


assertMethodNotAllowed = (method) ->
  try
    integration.request(method: method)
    assert.fail("expected #{method} to throw an error")
  catch e
    assert.equal e.status, 415
    assert.equal e.body, "The #{method.toUpperCase()} method is not allowed"
    assert.deepEqual e.headers,
      'Allow': 'GET, POST'
      'Content-Type': 'text/plain'
