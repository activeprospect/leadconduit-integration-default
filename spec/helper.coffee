flat = require 'flat'
dotaccess = require 'dotaccess'
fields = require 'leadconduit-fields'


variables = (vars={}) ->
  flatVars = flat.flatten(vars)

  defaultVars =
    url: 'http://externalservice'
    method: 'post'
    lead:
      first_name: 'Joe'
      last_name: 'Blow'
      email: 'JBLOW@TEST.COM'
      phone_1: '512-789-1111'

  for key, value of flatVars
    dotaccess.set(defaultVars, key, value, true)

  defaultVars.lead = fields.buildLeadVars(defaultVars.lead)
  defaultVars


module.exports =
  variables: variables