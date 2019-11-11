_ = require('lodash')
dotaccess = require('dotaccess')
mimecontent = require('mime-content')
mimeparse = require('mimeparse')
querystring = require('querystring')
xmlbuilder = require('xmlbuilder')
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
    throw new HttpError(405, { 'Content-Type': 'text/plain', Allow: 'GET, POST' }, "The #{method.toUpperCase()} method is not allowed")

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
    redirUrl = redirUrl[0] if _.isArray(redirUrl)
    try
      redirUrl = url.parse(redirUrl)
      unless redirUrl.slashes and (redirUrl.protocol == 'http:' or redirUrl.protocol == 'https:')
        throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url')
    catch e
      throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url')

  normalizeTrustedFormCertUrl(query)

  if method == 'get'
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
      body = req.body?.trim()
      return query unless body
      parsed = mimecontent(body, mimeType)

      # if form URL encoding, convert dot notation keys
      if mimeType == 'application/x-www-form-urlencoded'
        try
          parsed = flat.unflatten(parsed)
        catch e
          formEncodedError = e.toString()
          throw new HttpError(400, {'Content-Type': 'text/plain'}, "Unable to parse body -- #{formEncodedError}.")

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


request.params = ->
  [
    {
      name: '*'
      type: 'Wildcard'
    }
    {
      name: 'redir_url'
      label: 'Redirect URL'
      type: 'url'
      description: 'Redirect to this URL after submission'
      variable: null
      required: false
      examples: ['http://myserver.com/thankyou.html']
    }
  ]

request.examples = (flowId, sourceId, params) ->
  baseUri = "/flows/#{flowId}/sources/#{sourceId}/submit"
  getUri = baseUri
  getUri = "#{getUri}?#{querystring.encode(params)}" if Object.keys(params)?.length

  postUri = baseUri
  if params.redir_url
    postUri = "#{postUri}?redir_url=#{encodeURIComponent(params.redir_url)}"
    delete params.redir_url

  xml = xmlbuilder.create('lead')
  for name, value of params
    xml.element(name, value)
  xmlBody = xml.end(pretty: true)

  [
    {
      method: 'POST'
      uri: postUri
      headers:
        'Accept': 'application/json'
        'Content-Type': 'application/x-www-form-urlencoded'
      body: querystring.encode(params)
    }
    {
      method: 'GET'
      uri: getUri
      headers:
        'Accept': 'application/json'
    }
    {
      method: 'POST'
      uri: postUri
      headers:
        'Accept': 'application/json'
        'Content-Type': 'application/json'
      body: JSON.stringify(params, null, 2)
    }
    {
      method: 'POST'
      uri: postUri
      headers:
        'Accept': 'text/xml'
        'Content-Type': 'text/xml'
      body: xmlBody
    }
    {
      method: 'POST'
      uri: postUri
      headers:
        'Accept': 'text/xml'
        'Content-Type': 'application/x-www-form-urlencoded'
      body: querystring.encode(params)
    }
  ]


request.variables = ->
  [
    { name: 'trustedform_cert_url', type: 'string', description: 'URL to the TrustedForm Certificate' },
    { name: '*', type: 'wildcard' }
  ]


#
# Response Function ------------------------------------------------------
#

response = (req, vars, fieldIds = ['outcome', 'reason', 'lead.id', 'price']) ->
  mimeType = selectMimeType(req.headers['Accept'])

  statusCode = 201

  # special behavior for ping requests:
  # 1. do not attempt to include lead id on ping responses. the handler does not provide it.
  # 2. if the price is $0, return 'failure'
  # 3. return HTTP 200 instead of HTTP 201
  if isPing(req)
    # set outcome to failure if necessary
    unless vars.price > 0
      vars.outcome = 'failure'
      vars.reason = 'no bid'
    # return 200
    statusCode = 200
    # omit lead id
    fieldIds = fieldIds.filter (fieldId) ->
      fieldId != 'lead.id'

  body = buildBody(mimeType, fieldIds, vars)

  # parse the query string
  uri = url.parse(req.uri)
  query = flat.unflatten(querystring.parse(uri.query))

  # find the redir url
  redirUrl = if _.isArray(query.redir_url) then query.redir_url[0] else query.redir_url

  status = if redirUrl? then 303 else statusCode

  headers =
    'Content-Type': mimeType,
    'Content-Length': body.length

  headers['Location'] = redirUrl if redirUrl?

  status: status
  headers: headers
  body: body


response.variables = (forPing) ->
  if forPing
    [
      { name: 'outcome', type: 'string', description: 'The outcome of the ping (default is success)' },
      { name: 'reason', type: 'string', description: 'If the ping outcome was a failure, this is the reason' }
      { name: 'price', type: 'number', description: 'The bid price of the lead' }
    ]
  else
    [
      { name: 'lead.id', type: 'string', description: 'The lead identifier that the source should reference' },
      { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' },
      { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' }
      { name: 'price', type: 'number', description: 'The price of the lead' }
    ]


#
# Helpers ----------------------------------------------------------------
#

buildBody = (mimeType, fieldIds, vars) ->
  body = null
  if mimeType == 'text/plain'
    body = ''
    body += "lead_id:#{vars.lead.id}\n" if fieldIds.include('lead.id')
    body += "outcome:#{vars.outcome}\n" if fieldIds.include('outcome')
    body += "reason:#{vars.reason}\n" if fieldIds.include('reason')
    body += "price:#{vars.price || 0}\n" if fieldIds.include('price')
  else
    json = {}
    for field in fieldIds
      value = dotaccess.get(vars, field)?.valueOf()
      json[field] = value unless value == undefined
    json = flat.unflatten(json)

    json.price ?= 0

    if mimeType == 'application/xml' or mimeType == 'text/xml'
      body = xmlbuilder.create(result: json).end(pretty: true)
    else
      body = JSON.stringify(json)
  body


isPing = (req) ->
  return false unless req?.uri
  uri = url.parse(req.uri)
  !!uri?.pathname?.match(/\/ping$/)


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
  name: 'Standard'
  request: request
  response: response
  pingable: true


