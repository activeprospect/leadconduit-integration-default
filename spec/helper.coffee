dotaccess = require('dotaccess')
flat = require('flat')
types = require('leadconduit-integration').test.types


module.exports =
  variables: (requestVariables) ->
    parse = types.parser(requestVariables)

    (override={}) ->

      override = flat.flatten(override, safe: true)

      vars =
        url: 'http://externalservice'
        method: 'post'
        lead:
          first_name: 'Joe'
          last_name: 'Blow'
          email: 'JBLOW@TEST.COM'
          phone_1: '512-789-1111'
        price: 1.5

      for key, value of override
        dotaccess.set(vars, key, value, true)

      parse(vars)
