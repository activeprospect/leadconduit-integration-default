mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')
u = require('url')

acceptHeader = 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7'

supportedMimeTypes = [
  'application/json',
  'application/xml',
  'text/xml',
]

supportedMimeTypeLookup = supportedMimeTypes.reduce(((lookup, mimeType) ->
  lookup[mimeType] = true
  lookup
), {})

isValidUrl = (url) ->
  url.protocol? and
    url.protocol.match(/^http[s]?:/) and
    url.slashes and
    url.hostname?


#
# Request Function -------------------------------------------------------
#

request = (vars) ->

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

  # build lead data
  content = {}
  for key, value of vars.lead
    content[key] = value?.toString()

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


request.variables = ->
  [
    { name: 'url', description: 'Server URL', required: true }
    { name: 'method', description: 'HTTP method (GET or POST)', required: true }
  ]


#
# Response Function ------------------------------------------------------
#

response = (vars, req, res) ->

  contentType = res.headers['Content-Type']

  # ensure content type header was returned by server
  unless contentType?
    return { outcome: 'error', reason: 'No Content-Type specified in server response' }

  # ensure valid mime type
  mimeType = mimeparse.bestMatch(supportedMimeTypes, contentType)
  unless supportedMimeTypeLookup[mimeType]?
    return { outcome: 'error', reason: 'Unsupported Content-Type specified in server response' }

  parsed = mimecontent(res.body, mimeType)

  if mimeType == 'application/xml' or mimeType == 'text/xml'
    parsed = parsed.toObject(explicitArray: false, explicitRoot: false, mergeAttrs: true)

  parsed.outcome = parsed.outcome || 'success'
  parsed.reason  = parsed.reason  || ''

  parsed


response.variables = ->
  [
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' }
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
  ]


#
# Exports ----------------------------------------------------------------
#

module.exports =
  name: 'Generic POST',
  request: request,
  response: response


