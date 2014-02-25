mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')

HttpError = (status, headers, body) ->
  Error.call(@)
  Error.captureStackTrace(@, arguments.callee)
  @status = status
  @headers = headers
  @body = body
  @name = 'HttpError'

HttpError.prototype.__proto__ = Error.prototype;


supportedMimeTypes = [
  'application/x-www-form-urlencoded',
  'application/json',
  'application/xml',
  'text/xml',
]

supportedMimeTypeLookup = supportedMimeTypes.reduce(((lookup, mimeType) ->
  lookup[mimeType] = true
  lookup
), {})


#
# Request Function -------------------------------------------------------
#

request = (req) ->

  method = req.method.toLowerCase()
  if method != 'get' and method != 'post'
    throw new HttpError(405, { 'Content-Type': 'text/plain', Allow: 'GET, POST' }, "The #{method.toUpperCase()} method is not allowed")

  query = querystring.parse(req.query)


  if method == 'get'
    querystring.parse(req.query);

  else if (method == 'post')

    if req.headers['Content-Length']? or req.headers['Transfer-Encoding'] == 'chunked'
      # assume a request body

      # ensure a content type header
      contentType = req.headers['Content-Type']
      unless contentType
        throw new HttpError(415, {'Content-Type': 'text/plain'}, 'Content-Type header is required')

      # ensure valid mime type
      mimeType = mimeparse.bestMatch(supportedMimeTypes, contentType)
      unless supportedMimeTypeLookup[mimeType]?
        throw new HttpError(415, {'Content-Type': 'text/plain'}, "MIME type in Content-Type header is not supported. Use only #{supportedMimeTypes.join(', ')}.")

      # parse request body according the the mime type
      parsed = mimecontent(req.body, mimeType)

      # if XML, turn doc into an object
      if mimeType == 'application/xml' or mimeType == 'text/xml'
        parsed = parsed.toObject(explicitArray: false, explicitRoot: false, mergeAttrs: true)

      # merge query string data into data parsed from request body
      for name, value of query
        parsed[name] ?= value

      parsed

    else
      # assume no request body





request.variables = ->
  []


#
# Response Function ------------------------------------------------------
#

response = (req, vars) ->
  supportedMimeTypes = [
    'application/json',
    'application/xml',
    'text/xml'
  ]

  accept = req.headers['Accept'] or 'application/json'
  mimeType = mimeparse.bestMatch(supportedMimeTypes, accept)

  status = 201
  body = null
  if mimeType == 'application/xml' or mimeType == 'text/xml'
    xml = xmlbuilder.create('result')
    xml.element('lead_id', vars.lead.id)
    xml.element('outcome', vars.outcome)
    xml.element('reason', vars.reason)
    body = xml.end(pretty: true)
  else if mimeType == 'application/json'
    body = JSON.stringify(
      lead_id: vars.lead.id
      outcome: vars.outcome
      reason: vars.reason
    )
  else if mimeType == 'text/plain'
    body = ''
    body += "lead_id:#{vars.lead.id}\n"
    body += "outcome:#{vars.outcome}\n"
    body += "reason:#{vars.reason}\n"

  headers =
    'Content-Type': mimeType,
    'Content-Length': body.length

  [status, headers, body]


response.variables = ->
  [
    { name: 'lead.id', type: 'string', description: 'The lead identifier that the source should reference' },
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' },
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
  ]


#
# Exports ----------------------------------------------------------------
#

module.exports =
  request: request,
  response: response


