assert = require('chai').assert
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
      assert.equal e.status, 415
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



assertParses = (contentType, body) ->
  req =
    method: 'POST'
    headers:
      'Content-Length': body.length
      'Content-Type': contentType
    body: body

  expected =
    first_name: 'Joe',
    last_name: 'Blow',
    email: 'jblow@test.com',
    phone_1: '5127891111'

  result = integration.request(req)
  assert.deepEqual result, expected


assertMethodNotAllowed = (method) ->
  try
    integration.request(method: method)
    assert.fail("expected #{method} to throw an error")
  catch e
    assert.equal e.status, 405
    assert.equal e.body, "The #{method.toUpperCase()} method is not allowed"
    assert.deepEqual e.headers,
      'Allow': 'GET, POST'
      'Content-Type': 'text/plain'