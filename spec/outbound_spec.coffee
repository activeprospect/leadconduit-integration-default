assert = require('chai').assert
nock = require('nock')
integration = require('../src/outbound')
variables = require('./helper').variables

describe 'Outbound Request', ->

  afterEach ->
    @service.done() if @service?

  it 'should require url variable', ->
    vars = variables()
    delete vars.url
    try
      integration.handle(vars)
      assert.fail('expected error when url variable is missing')
    catch e
      assert.equal e.message, 'Cannot connect to service because URL is missing'

  it 'should require valid url variable', ->
    vars = variables()
    vars.url = 'donkeykong'
    try
      integration.handle(vars)
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

  it 'should send accept header', (done) ->
    @service = nock('http://externalservice')
      .matchHeader('accept', 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7')
      .post('/')
      .reply(200, {})
    integration.handle variables(), done

  it 'should encode content sent via get as querystring', (done) ->
    @service = nock('http://externalservice')
      .get('/?first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111')
      .reply(200, {})
    integration.handle variables(method: 'get'), done

  it 'should merge content sent via get over querystring', (done) ->
    @service = nock('http://externalservice')
      .get('/?first_name=Joe&aff_id=123&last_name=Blow&email=jblow%40test.com&phone_1=5127891111')
      .reply(200, {})
    integration.handle variables(url: 'http://externalservice?first_name=Bobby&aff_id=123', method: 'get'), done

  it 'should handle null variable', (done) ->
    @service = nock('http://externalservice')
      .get('/?first_name=&last_name=Blow&email=jblow%40test.com&phone_1=5127891111')
      .reply(200, {})
    integration.handle variables(lead: { first_name: null }, method: 'get'), done

  it 'should handle undefined variable', (done) ->
    @service = nock('http://externalservice')
      .get('/?last_name=Blow&email=jblow%40test.com&phone_1=5127891111')
      .reply(200, {})
    integration.handle variables(lead: { first_name: undefined }, method: 'get'), done

  it 'should encode content sent as post', (done) ->
    @service = nock('http://externalservice')
      .post '/', 'first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111'
      .reply(200, {})
    integration.handle variables(), done

  it 'should set content length of post', (done) ->
    @service = nock('http://externalservice')
      .matchHeader('content-length', 71)
      .post '/'
      .reply(200, {})
    integration.handle variables(), done

  it 'should set content type of post', (done) ->
    @service = nock('http://externalservice')
      .matchHeader('content-type', 'application/x-www-form-urlencoded')
      .post '/'
      .reply(200, {})
    integration.handle variables(), done


describe 'Outbound Response', ->

  it 'should default outcome to "error"', (done) ->
    @service = nock('http://externalservice')
      .post '/'
      .reply(200, id: 42)
    integration.handle variables(), (err, event) ->
      return done(err) if err?
      assert.equal event.outcome, 'error'
      done()

  it 'should default outcome to an error message', (done) ->
    @service = nock('http://externalservice')
      .post '/'
      .reply(200, id: 42)
    integration.handle variables(), (err, event) ->
      return done(err) if err?
      assert.equal event.reason, 'Unrecognized response'
      done()

  it 'should preserve existing reason even if outcome defaults to "error"', (done) ->
    @service = nock('http://externalservice')
      .post '/'
      .reply(200, id: 42, reason: 'Big bada boom')
    integration.handle variables(), (err, event) ->
      return done(err) if err?
      assert.equal event.outcome, 'error'
      assert.equal event.reason, 'Big bada boom'
      done()


  it 'should parse XML response', (done) ->
    @service = nock('http://externalservice')
      .post '/'
      .reply(200, xmlBody(), 'Content-Type': 'text/xml')
    integration.handle variables(), (err, event) ->
      return done(err) if err?
      expected =
        outcome: 'success'
        reason: ''
        lead:
          id: '1234'
          last_name: 'Blow'
          email: 'jblow@test.com'
          phone_1: '5127891111'
      assert.deepEqual event, expected
      done()

  it 'should parse JSON response', (done) ->
    expected =
      outcome: 'success'
      reason: ''
      lead:
        id: '1234'
        last_name: 'Blow'
        email: 'jblow@test.com'
        phone_1: '5127891111'
    @service = nock('http://externalservice')
      .post '/'
      .reply(200, expected)
    integration.handle variables(), (err, event) ->
      return done(err) if err?
      assert.deepEqual event, expected
      done()

assertMethodNotAllowed = (method) ->
  vars = variables()
  vars.method = method
  try
    integration.handle(vars)
    assert.fail('expected integration to throw an error')
  catch e
    assert.equal e.message, "Unsupported HTTP method #{method.toUpperCase()}. Use GET or POST."

xmlBody = ->
  '''
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
