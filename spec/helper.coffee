
variables = ->
  url: 'http://myserver.com/leads'
  method: 'post'
  lead:
    first_name: 'Joe'
    last_name: 'Blow'
    email:
      raw: 'JBLOW@TEST.COM'
      normal: 'jblow@test.com'
      domain: 'test.com'
      host: 'test'
      tld: 'com'
    phone_1:
      raw: '512-789-1111'
      normal: '5127891111'
      area: '512'
      exchange: '789'
      line: '1111'

module.exports =
  variables: variables