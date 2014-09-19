fields = require 'leadconduit-fields'


variables = ->
  url: 'http://myserver.com/leads'
  method: 'post'
  lead: fields.buildLeadVars
    first_name: 'Joe'
    last_name: 'Blow'
    email: 'JBLOW@TEST.COM'
    phone_1: '512-789-1111'


module.exports =
  variables: variables