_ = require('lodash')
mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')
fields = require('leadconduit-fields')
flat = require('flat')
url = require('url')
HttpError = require('leadconduit-integration').HttpError


supportedMimeTypes = [
  'application/x-www-form-urlencoded',
  'application/json',
  'application/xml',
  'text/xml'
]

supportedMimeTypeLookup = supportedMimeTypes.reduce(((lookup, mimeType) ->
  lookup[mimeType] = true
  lookup
), {})


#
# Request Function -------------------------------------------------------
#

request = (req) ->

  # ensure supported method
  method = req.method?.toLowerCase()
  if method != 'get' and method != 'post'
    throw new HttpError(415, { 'Content-Type': 'text/plain', Allow: 'GET, POST' }, "The #{method.toUpperCase()} method is not allowed")

  # ensure acceptable content type, preferring JSON
  mimeType = selectMimeType(req.headers['Accept'])
  unless mimeType
    throw new HttpError(406, { 'Content-Type': 'text/plain' }, "Not capable of generating content according to the Accept header")

  # parse the query string
  uri = url.parse(req.uri, true)
  query = flat.unflatten(uri.query)

  # find the redir url
  redirUrl = query.redir_url

  if redirUrl?
    redirUrl = url.parse(redirUrl)
    unless redirUrl.slashes and (redirUrl.protocol == 'http:' or redirUrl.protocol == 'https:')
      throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url')

  normalizeTrustedFormCertUrl(query)

  if method == 'get' or req.headers['Content-Length'] == 0
    query

  else if (method == 'post')

    if req.headers['Content-Length']? or req.headers['Transfer-Encoding'] == 'chunked'
      # assume a request body

      # ensure a content type header
      contentType = req.headers['Content-Type']
      unless contentType
        throw new HttpError(415, {'Content-Type': 'text/plain'}, 'Content-Type header is required')

      # ensure valid mime type
      mimeType = selectMimeType(req.headers['Content-Type'])
      unless supportedMimeTypeLookup[mimeType]?
        throw new HttpError(406, {'Content-Type': 'text/plain'}, "MIME type in Content-Type header is not supported. Use only #{supportedMimeTypes.join(', ')}.")

      # parse request body according the the mime type
      return unless req.body
      parsed = mimecontent(req.body, mimeType)

      # if form URL encoding, convert dot notation keys
      if mimeType == 'application/x-www-form-urlencoded'
        parsed = flat.unflatten(parsed)

      # if XML, turn doc into an object
      if mimeType == 'application/xml' or mimeType == 'text/xml'
        try
          parsed = parsed.toObject(explicitArray: false, explicitRoot: false, mergeAttrs: true)
        catch e
          xmlError = e.toString().replace(/\r?\n/g, " ")
          throw new HttpError(400, {'Content-Type': 'text/plain'}, "Body does not contain XML or XML is unparseable -- #{xmlError}.")


      # merge query string data into data parsed from request body
      _.merge(parsed, query)

      normalizeTrustedFormCertUrl(parsed)

      parsed

    else
      # assume no request body
      query




request.variables = ->
  [
    { name: 'trustedform_cert_url', type: 'string', description: 'URL to the TrustedForm Certificate' },
    { name: '*', type: 'wildcard' }
  ]


#
# Response Function ------------------------------------------------------
#

response = (req, vars) ->
  mimeType = selectMimeType(req.headers['Accept'])

  body = null
  if mimeType == 'application/xml' or mimeType == 'text/xml'
    xml = xmlbuilder.create('result')
    xml.element('outcome', vars.outcome)
    xml.element('reason', vars.reason)
    xml.element('lead').element('id', vars.lead.id)
    body = xml.end(pretty: true)
  else if mimeType == 'application/json'
    body = JSON.stringify(
      outcome: vars.outcome
      reason: vars.reason
      lead: { id: vars.lead.id }
    )
  else if mimeType == 'text/plain'
    body = ''
    body += "lead_id:#{vars.lead.id}\n"
    body += "outcome:#{vars.outcome}\n"
    body += "reason:#{vars.reason}\n"

  # parse the query string
  uri = url.parse(req.uri)
  query = flat.unflatten(querystring.parse(uri.query))

  # find the redir url
  redirUrl = query.redir_url

  status = if redirUrl? then 303 else 201

  headers =
    'Content-Type': mimeType,
    'Content-Length': body.length

  headers['Location'] = redirUrl if redirUrl?

  status: status
  headers: headers
  body: body


response.variables = ->
  [
    { name: 'lead.id', type: 'string', description: 'The lead identifier that the source should reference' },
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' },
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
  ]


#
# Helpers ----------------------------------------------------------------
#

selectMimeType = (contentType) ->
  contentType = contentType or 'application/json'
  contentType = 'application/json' if contentType == '*/*'
  mimeparse.bestMatch(supportedMimeTypes, contentType)


normalizeTrustedFormCertUrl = (obj) ->
  for param, value of obj
    if param?.toLowerCase() == 'xxtrustedformcerturl'
      obj.trustedform_cert_url = value
      delete obj[param]




#
# Exports ----------------------------------------------------------------
#

module.exports =
  name: 'Generic POST'
  request: request,
  response: response


