inbound = require('./inbound')
flat = require('flat')
_ = require('lodash')

#
# Response Function ------------------------------------------------------
#

response = (req, vars) ->

  fieldIds = []
  if vars.appended
  # only send appended fields, but those need to be under an appended object to have the correct fieldId
    appended = appended: vars.appended
    fieldIds = _.keys(flat.flatten(appended, safe: true))

  fieldIds.push('outcome', 'reason', 'lead.id')

  inbound.response(req, vars, fieldIds)

response.variables = ->
  [
    { name: 'lead.id', type: 'string', description: 'The lead identifier that the source should reference' }
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' }
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
    { name: 'appended.*', type: 'wildcard'}
  ]

#
# Exports ----------------------------------------------------------------
#

module.exports =
  request: inbound.request
  response: response