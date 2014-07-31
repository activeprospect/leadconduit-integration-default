assert = require('chai').assert
integration = require('../src/outbound')
variables = require('./helper').variables

describe 'Outbound Request', ->

  it 'should require url variable', ->
    vars = variables()
    delete vars.url
    try
      integration.request(vars)
      assert.fail('expected error when url variable is missing')
    catch e
      assert.equal e.message, 'Cannot connect to service because URL is missing'

  it 'should require valid url variable', ->
    vars = variables()
    vars.url = 'donkeykong'
    try
      integration.request(vars)
      assert.fail('expected error when url variable is invalid')
    catch e
      assert.equal e.message, 'Cannot connect to service because URL is invalid'

  it 'should not allow head', ->
    assertMethodNotAllowed('head')

  it 'should not allow put', ->
    assertMethodNotAllowed('put')

  it 'should not allow delete', ->
    assertMethodNotAllowed('delete')

  it 'should not allow patch', ->
    assertMethodNotAllowed('patch')

  it 'should send accept header', ->
    req = integration.request(variables())
    assert.equal req.headers['Accept'], 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7'

  it 'should encode content sent via get as querystring', ->
    vars = variables()
    vars.method = 'get'
    req = integration.request(vars)
    assert.equal req.url , 'http://myserver.com/leads?first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'

  it 'should merge content sent via get over querystring', ->
    vars = variables()
    vars.url = "#{vars.url}?first_name=Bobby&aff_id=123"
    vars.method = 'get'
    req = integration.request(vars)
    assert.equal req.url , 'http://myserver.com/leads?first_name=Joe&aff_id=123&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'

  it 'should handle null variable', ->
    vars = variables()
    vars.lead.first_name = null
    req = integration.request(vars)
    assert.equal req.body, 'first_name=&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'

  it 'should handle undefined variable', ->
    vars = variables()
    vars.lead.first_name = undefined
    req = integration.request(vars)
    assert.equal req.body, 'first_name=&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'

  it 'should encode content sent as post via querystring', ->
    req = integration.request(variables())
    assert.equal req.body, 'first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'

  it 'should set content length of post', ->
    req = integration.request(variables())
    assert.equal req.headers['Content-Length'], 71

  it 'should set content type of post', ->
    req = integration.request(variables())
    assert.equal req.headers['Content-Type'], 'application/x-www-form-urlencoded'


describe 'Outbound Response', ->
  it 'should parse XML response', ->
    vars = variables()
    req = integration.request(vars)
    res = xmlResponse()
    result = integration.response(vars, req, res)
    expected =
      outcome: 'success'
      reason: ''
      lead:
        id: '1234'
        last_name: 'Blow'
        email: 'jblow@test.com'
        phone_1: '5127891111'
    assert.deepEqual result, expected


  it 'should parse JSON response', ->
    expected =
      outcome: 'success'
      reason: ''
      lead:
        id: '1234'
        last_name: 'Blow'
        email: 'jblow@test.com'
        phone_1: '5127891111'
    vars = variables()
    req = integration.request(variables())
    res =
      status: 201
      headers:
        'Content-Type': 'application/json'
      body: JSON.stringify(expected)
    result = integration.response(vars, req, res)
    assert.deepEqual result, expected



assertMethodNotAllowed = (method) ->
  vars = variables()
  vars.method = method
  try
    integration.request(vars)
    assert.fail('expected integration to throw an error')
  catch e
    assert.equal e.message, "Unsupported HTTP method #{method.toUpperCase()}. Use GET or POST."


xmlResponse = ->
  body = '''
    <result>
      <outcome>success</outcome>
      <reason/>
      <lead>
        <id>1234</id>
        <last_name>Blow</last_name>
        <email>jblow@test.com</email>
        <phone_1>5127891111</phone_1>
      </lead>
    </result>
  '''
  status: 201
  headers:
    'Content-Type': 'text/xml'
  body: body