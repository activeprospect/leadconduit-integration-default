assert = require('chai').assert
integration = require('../src/inbound')
outbound = require('../src/outbound')
variables = require('./helper').variables


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
      integration.request(method: 'post', headers: { 'Content-Length': '1' })
      assert.fail("expected an error to be thrown when no content type is specified")
    catch e
      assert.equal e.status, 415
      assert.equal e.body, 'Content-Type header is required'
      assert.deepEqual e.headers, 'Content-Type': 'text/plain'

  it 'should require supported mimetype', ->
    try
      integration.request(method: 'post', headers: { 'Content-Length': '1', 'Content-Type': 'Monkies' })
      assert.fail("expected an error to be thrown when no content type is specified")
    catch e
      assert.equal e.status, 406
      assert.equal e.body, 'MIME type in Content-Type header is not supported. Use only application/x-www-form-urlencoded, application/json, application/xml, text/xml.'
      assert.deepEqual e.headers, 'Content-Type': 'text/plain'

  it 'should parse posted form url encoded body', ->
    body = 'first_name=Joe&last_name=Blow&email=jblow@test.com&phone_1=5127891111'
    assertParses 'application/x-www-form-urlencoded', body

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


describe 'Inbound Response', ->

  vars = variables()
  vars.lead = { id: '123' }
  vars.outcome = 'failure'
  vars.reason = 'bad!'

  it 'should respond with json', ->
    req = outbound.request(variables())
    req.headers['Accept'] = 'application/json'
    res = integration.response(req, vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'application/json', 'Content-Length': 57
    assert.equal res.body, '{"outcome":"failure","reason":"bad!","lead":{"id":"123"}}'

  it 'should default to json', ->
    req = outbound.request(variables())
    req.headers['Accept'] = '*/*'
    res = integration.response(req, vars)
    assert.deepEqual res.headers['Content-Type'],  'application/json'

  it 'should respond with text xml', ->
    req = outbound.request(variables())
    req.headers['Accept'] = 'text/xml'
    res = integration.response(req, vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'text/xml', 'Content-Length': 129
    assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n</result>'

  it 'should respond with application xml', ->
    req = outbound.request(variables())
    req.headers['Accept'] = 'application/xml'
    res = integration.response(req, vars)
    assert.equal res.status, 201
    assert.deepEqual res.headers, 'Content-Type': 'application/xml', 'Content-Length': 129
    assert.equal res.body, '<?xml version="1.0"?>\n<result>\n  <outcome>failure</outcome>\n  <reason>bad!</reason>\n  <lead>\n    <id>123</id>\n  </lead>\n</result>'




assertParses = (contentType, body) ->
  req =
    method: 'POST'
    headers:
      'Content-Length': body.length
      'Content-Type': contentType
    body: body

  expected =
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