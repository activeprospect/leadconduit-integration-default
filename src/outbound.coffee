_ = require('lodash')
mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')
flat = require('flat')
u = require('url')



#
# Request Function --------------------------------------------------------
#

request = (vars) ->

  url = u.parse(vars.url)
  method = vars.method?.toUpperCase() || 'POST'

  # the preferred resource content-types
  acceptHeader = 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7'

  # build lead data
  content = {}
  for key, value of flat.flatten(vars.lead)
    # fields with undefined as the value are not included
    continue if typeof value == 'undefined'
    # use valueOf to ensure the normal version is sent for all richly typed values
    content[key] = value?.valueOf() ? null

  if method == 'GET'

    # build query string, merging 'over' existing querystring
    query = querystring.parse(url.query or '')
    for key, value of content
      query[key] = value

    url.query = query
    delete url.search

    url: u.format(url)
    method: method,
    headers:
      'Accept': acceptHeader

  else if method == 'POST'

    # URL encoded post body
    content = querystring.encode(content)

    url: vars.url
    method: method
    headers:
      'Content-Type': 'application/x-www-form-urlencoded'
      'Content-Length': content.length
      'Accept': acceptHeader
    body: content



#
# Response Function --------------------------------------------------------
#

response = (vars, req, res) ->
  body = res.body

  contentType = res.headers['Content-Type']

  # ensure content type header was returned by server
  unless contentType?
    return outcome: 'error', reason: 'No Content-Type specified in server response'

  # ensure valid mime type
  mimeType = bestMimeType(contentType)
  unless mimeType
    return outcome: 'error', reason: 'Unsupported Content-Type specified in server response'

  event = mimecontent(body, mimeType)

  if mimeType == 'application/xml' or mimeType == 'text/xml'
    event = event.toObject(explicitArray: false, explicitRoot: false, mergeAttrs: true)

  if !event.outcome?
    event =
      outcome: vars.default_outcome or 'error'
      reason: event.reason or 'Unrecognized response'

  event



#
# Variables --------------------------------------------------------------
#

request.variables = ->
  [
    { name: 'url', description: 'Server URL', type: 'string', required: true }
    { name: 'method', description: 'HTTP method (GET or POST)', type: 'string', required: true }
    { name: 'default_outcome', description: 'Outcome to return if recipient returns none (success, failure, error). If not specified, "error" will be used.', type: 'string' }
    { name: 'lead.*', type: 'wildcard', required: true }
  ]

response.variables = ->
  [
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' }
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
  ]


#
# Helpers ----------------------------------------------------------------
#


supportedMimeTypes = [
  'application/json',
  'application/xml',
  'text/xml',
]


supportedMimeTypeLookup = supportedMimeTypes.reduce(((lookup, mimeType) ->
  lookup[mimeType] = true
  lookup
), {})


bestMimeType = (contentType) ->
  mimeType = mimeparse.bestMatch(supportedMimeTypes, contentType)
  unless supportedMimeTypeLookup[mimeType]?
    mimeType = null
  mimeType


isValidUrl = (url) ->
  url.protocol? and
  url.protocol.match(/^http[s]?:/) and
  url.slashes and
  url.hostname?


validate = (vars) ->
  if vars.default_outcome? and !vars.default_outcome.match(/success|failure|error/)
    return 'default outcome must be "success", "failure" or "error"'

  # validate URL
  unless vars.url?
    return 'URL is required'

  url = u.parse(vars.url)

  unless isValidUrl(url)
    return 'URL must be valid'

  # validate method
  method = vars.method?.toUpperCase() || 'POST'
  unless method == 'GET' or method == 'POST'
    return "Unsupported HTTP method - use GET or POST"





#
# Exports ----------------------------------------------------------------
#

module.exports =
  name: 'Generic POST'
  request: request
  response: response
  validate: validate

