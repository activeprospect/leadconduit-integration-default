assert = require('chai').assert
integration = require('../src/verbose')
types = require('leadconduit-types')

describe 'Inbound Verbose Response', ->

  before ->
    @vars =
      outcome: 'success'
      lead:
        id: '1234'
      appended:
        briteverify:
          email:
            status: 'valid'
            disposable: 'false'
            role_address: 'false'
            outcome: 'success'

  it 'should set appended fields correctly in JSON response', ->
    req =
      uri: 'http://example.com'
      headers:
        'Accept': 'application/json'
    expected =
      status: 201
      headers:
        'Content-Type': 'application/json'
        'Content-Length': 162
      body: '{"appended":{"briteverify":{"email":{"status":"valid","disposable":"false","role_address":"false","outcome":"success"}}},"outcome":"success","lead":{"id":"1234"}}'
    assert.deepEqual integration.response(req, @vars), expected

  it 'should set appended fields correctly in XML response', ->
    req =
      uri: 'http://example.com'
      headers:
        'Accept': 'application/xml'
    expected =
      status: 201
      headers:
        'Content-Type': 'application/xml'
        'Content-Length': 359
      body: '<?xml version=\"1.0\"?>\n<result>\n  <appended>\n    <briteverify>\n      <email>\n        <status>valid</status>\n        <disposable>false</disposable>\n        <role_address>false</role_address>\n        <outcome>success</outcome>\n      </email>\n    </briteverify>\n  </appended>\n  <outcome>success</outcome>\n  <reason/>\n  <lead>\n    <id>1234</id>\n  </lead>\n</result>'
    assert.deepEqual integration.response(req, @vars), expected

  it 'should respond correctly when no fields are appended', ->
    req =
      uri: 'http://example.com'
      headers:
        'Accept': 'application/json'
    vars =
      outcome: 'success'
      lead:
        id: '1234'
    expected =
      status: 201
      headers:
        'Content-Type': 'application/json'
        'Content-Length': 42
      body: '{"outcome":"success","lead":{"id":"1234"}}'
    assert.deepEqual integration.response(req, vars), expected

  it 'should respond correctly with rich appended fields', ->
    req =
      uri: 'http://example.com'
      headers:
        'Accept': 'application/xml'
    vars =
      outcome: 'success'
      lead:
        id: '1234'
      appended:
        briteverify:
          email:
            status: 'valid'
            disposable: types.boolean.parse('false')
            role_address: types.boolean.parse('false')
            outcome: 'success'
            billable: types.number.parse('1')
    expected =
      status: 201
      headers:
        'Content-Type': 'application/xml'
        'Content-Length': 390
      body: '<?xml version=\"1.0\"?>\n<result>\n  <appended>\n    <briteverify>\n      <email>\n        <status>valid</status>\n        <disposable>false</disposable>\n        <role_address>false</role_address>\n        <outcome>success</outcome>\n        <billable>1</billable>\n      </email>\n    </briteverify>\n  </appended>\n  <outcome>success</outcome>\n  <reason/>\n  <lead>\n    <id>1234</id>\n  </lead>\n</result>'
    assert.deepEqual integration.response(req, vars), expected