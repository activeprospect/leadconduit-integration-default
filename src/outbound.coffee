_ = require('lodash')
mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')
request = require('request')
flat = require('flat')
u = require('url')



#
# Handle Function --------------------------------------------------------
#

handle = (vars, callback) ->
  options = req(vars)
  request options, (err, res, body) ->
    return callback(err) if err?

    parsed = parseResponseBody(res.headers['content-type'], body)

    if !parsed.outcome?
      parsed =
        outcome: 'error'
        reason: parsed.reason or 'Unrecognized response'

    callback null, parsed



#
# Variables --------------------------------------------------------------
#

requestVariables = ->
  [
    { name: 'url', description: 'Server URL', type: 'string', required: true }
    { name: 'method', description: 'HTTP method (GET or POST)', type: 'string', required: true }
    { name: 'lead.*', type: 'wildcard', required: true }
  ]

responseVariables = ->
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


parseResponseBody = (contentType, body) ->
  return body if _.isPlainObject body

  # ensure content type header was returned by server
  unless contentType?
    return outcome: 'error', reason: 'No Content-Type specified in server response'

  # ensure valid mime type
  mimeType = bestMimeType(contentType)
  unless mimeType
    return outcome: 'error', reason: 'Unsupported Content-Type specified in server response'

  parsed = mimecontent(body, mimeType)

  if mimeType == 'application/xml' or mimeType == 'text/xml'
    parsed = parsed.toObject(explicitArray: false, explicitRoot: false, mergeAttrs: true)

  parsed


req = (vars) ->

  # validate URL
  unless vars.url?
    throw new Error("Cannot connect to service because URL is missing")

  url = u.parse(vars.url)

  unless isValidUrl(url)
    throw new Error("Cannot connect to service because URL is invalid")

  # validate method
  method = vars.method?.toUpperCase() || 'POST'

  unless method == 'GET' or method == 'POST'
    throw new Error("Unsupported HTTP method #{method}. Use GET or POST.")

  # the preferred resource content-types
  acceptHeader = 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7'

  # build lead data
  content = {}
  for key, value of flat.flatten(vars.lead)
    content[key] = value?.valueOf()

  if method == 'GET'

    # build query string, merging 'over' existing querystring
    query = querystring.parse(url.query or '')
    for key, value of content
      query[key] = value ? null

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
# Exports ----------------------------------------------------------------
#

module.exports =
  name: 'Generic POST'
  handle: handle
  requestVariables: requestVariables
  responseVariables: responseVariables


