const _ = require('lodash');
const dotaccess = require('dotaccess');
const mimecontent = require('mime-content');
const mimeparse = require('mimeparse');
const querystring = require('querystring');
const xmlbuilder = require('xmlbuilder');
const flat = require('flat');
const { HttpError } = require('leadconduit-integration');
const { isPing, parseQuery } = require('./helpers');

const supportedMimeTypes = [
  'application/x-www-form-urlencoded',
  'application/json',
  'application/xml',
  'text/xml'
];

const supportedMimeTypeLookup = supportedMimeTypes.reduce(function (lookup, mimeType) {
  lookup[mimeType] = true;
  return lookup;
}, {});

//
// Request Function -------------------------------------------------------
//

const request = function (req) {
  // ensure supported method
  let e;
  const method = req.method != null ? req.method.toLowerCase() : undefined;
  if ((method !== 'get') && (method !== 'post')) {
    throw new HttpError(405, { 'Content-Type': 'text/plain', Allow: 'GET, POST' }, `The ${method.toUpperCase()} method is not allowed`);
  }

  // ensure acceptable content type, preferring JSON
  let mimeType = selectMimeType(req.headers.Accept);
  if (!mimeType) {
    throw new HttpError(406, { 'Content-Type': 'text/plain' }, 'Not capable of generating content according to the Accept header');
  }

  const query = parseQuery(req.uri);

  // find the redir url
  let redirUrl = query.redir_url;

  if (redirUrl != null) {
    if (_.isArray(redirUrl)) { redirUrl = redirUrl[0]; }
    try {
      redirUrl = new URL(redirUrl);
      if (redirUrl.protocol !== 'http:' && redirUrl.protocol !== 'https:') {
        throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url');
      }
    } catch (error) {
      e = error;
      throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url');
    }
  }

  const isLcPing = isPing(req);
  normalizeTrustedFormCertUrl(query, isLcPing);

  if (method === 'get') {
    return query;
  } else if (method === 'post') {
    if ((req.headers['Content-Length'] != null) || (req.headers['Transfer-Encoding'] === 'chunked')) {
      // assume a request body

      // ensure a content type header
      const contentType = req.headers['Content-Type'];
      if (!contentType) {
        throw new HttpError(415, { 'Content-Type': 'text/plain' }, 'Content-Type header is required');
      }

      // ensure valid mime type
      mimeType = selectMimeType(req.headers['Content-Type']);
      if (supportedMimeTypeLookup[mimeType] == null) {
        throw new HttpError(406, { 'Content-Type': 'text/plain' }, `MIME type in Content-Type header is not supported. Use only ${supportedMimeTypes.join(', ')}.`);
      }

      // parse request body according the mime type
      const body = req.body != null ? req.body.trim() : undefined;
      if (!body) { return query; }
      let parsed;
      try {
        parsed = mimecontent(body, mimeType);
      } catch (e) {
        if(mimeType === 'application/json') {
          // a common problem with inbound JSON is when values have embedded newlines or tabs; retry without those
          try {
            parsed = mimecontent(body.replace(/[\r\n\t]/g, ''), mimeType);
          } catch (e) {
            throw new HttpError(400, { 'Content-Type': 'text/plain' }, `Unable to parse JSON -- ${e}`);
          }
        } else {
          throw new HttpError(400, { 'Content-Type': 'text/plain' }, `Unable to parse body -- ${e}`);
        }
      }

      // if form URL encoding, convert dot notation keys
      if (mimeType === 'application/x-www-form-urlencoded') {
        try {
          parsed = flat.unflatten(parsed);
        } catch (error1) {
          e = error1;
          const formEncodedError = e.toString();
          throw new HttpError(400, { 'Content-Type': 'text/plain' }, `Unable to parse body -- ${formEncodedError}.`);
        }
      }

      // if XML, turn doc into an object
      if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
        try {
          parsed = parsed.toObject({ explicitArray: false, explicitRoot: false, mergeAttrs: true });
        } catch (error2) {
          e = error2;
          const xmlError = e.toString().replace(/\r?\n/g, ' ');
          throw new HttpError(400, { 'Content-Type': 'text/plain' }, `Body does not contain XML or XML is unparseable -- ${xmlError}.`);
        }
      }

      // merge query string data into data parsed from request body
      _.merge(parsed, query);

      normalizeTrustedFormCertUrl(parsed, isLcPing);

      return parsed;
    } else {
      // assume no request body
      return query;
    }
  }
};

request.params = () =>
  [
    {
      name: '*',
      type: 'Wildcard'
    },
    {
      name: 'redir_url',
      label: 'Redirect URL',
      type: 'url',
      description: 'Redirect to this URL after submission',
      variable: null,
      required: false,
      examples: ['http://myserver.com/thankyou.html']
    }
  ]
;

request.examples = function (flowId, sourceId, params) {
  const baseUri = `/flows/${flowId}/sources/${sourceId}/submit`;
  let getUri = baseUri;
  if (_.get(Object.keys(params), 'length')) { getUri = `${getUri}?${querystring.encode(params)}`; }

  let postUri = baseUri;
  if (params.redir_url) {
    postUri = `${postUri}?redir_url=${encodeURIComponent(params.redir_url)}`;
    delete params.redir_url;
  }

  const xml = xmlbuilder.create('lead');
  for (const name in params) {
    const value = params[name];
    xml.element(name, value);
  }
  const xmlBody = xml.end({ pretty: true });

  return [
    {
      method: 'POST',
      uri: postUri,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: querystring.encode(params)
    },
    {
      method: 'GET',
      uri: getUri,
      headers: {
        Accept: 'application/json'
      }
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(params, null, 2)
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        Accept: 'text/xml',
        'Content-Type': 'text/xml'
      },
      body: xmlBody
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        Accept: 'text/xml',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: querystring.encode(params)
    }
  ];
};

request.variables = () =>
  [
    { name: 'trustedform_cert_url', type: 'string', description: 'URL to the TrustedForm Certificate' },
    { name: '*', type: 'wildcard' }
  ]
;

//
// Response Function ------------------------------------------------------
//

const response = function (req, vars, fieldIds) {
  if (fieldIds == null) { fieldIds = ['outcome', 'reason', 'lead.id', 'price']; }
  const mimeType = selectMimeType(req.headers.Accept);

  let statusCode = 201;

  // special behavior for ping requests:
  // 1. do not attempt to include lead id on ping responses. the handler does not provide it.
  // 2. if the price is $0, return 'failure'
  // 3. return HTTP 200 instead of HTTP 201
  if (isPing(req)) {
    // set outcome to failure if necessary
    if (!(vars.price > 0)) {
      vars.outcome = 'failure';
      if (vars.reason == null) { vars.reason = 'no bid'; }
    }
    // return 200
    statusCode = 200;
    // omit lead id
    fieldIds = fieldIds.filter(fieldId => fieldId !== 'lead.id');
  }

  const body = buildBody(mimeType, fieldIds, vars);

  const query = parseQuery(req.uri);

  // find the redir url
  const redirUrl = _.isArray(query.redir_url) ? query.redir_url[0] : query.redir_url;

  const status = (redirUrl != null) ? 303 : statusCode;

  const headers = {
    'Content-Type': mimeType,
    'Content-Length': body.length
  };

  if (redirUrl != null) { headers.Location = redirUrl; }

  return {
    status,
    headers,
    body
  };
};

response.variables = function (forPing) {
  if (forPing) {
    return [
      { name: 'outcome', type: 'string', description: 'The outcome of the ping (default is success)' },
      { name: 'reason', type: 'string', description: 'If the ping outcome was a failure, this is the reason' },
      { name: 'price', type: 'number', description: 'The bid price of the lead' }
    ];
  } else {
    return [
      { name: 'lead.id', type: 'string', description: 'The lead identifier that the source should reference' },
      { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' },
      { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' },
      { name: 'price', type: 'number', description: 'The price of the lead' }
    ];
  }
};

//
// Helpers ----------------------------------------------------------------
//

const embeddedNumericRegex = /\.([0-9]+)\./; // e.g., "42" (but without quotes) from "foo.42.bar"

const buildBody = function (mimeType, fieldIds, vars) {
  let body = null;
  if (mimeType === 'text/plain') {
    body = '';
    if (fieldIds.include('lead.id')) { body += `lead_id:${vars.lead.id}\n`; }
    if (fieldIds.include('outcome')) { body += `outcome:${vars.outcome}\n`; }
    if (fieldIds.include('reason')) { body += `reason:${vars.reason}\n`; }
    if (fieldIds.include('price')) { body += `price:${vars.price || 0}\n`; }
  } else {
    let json = {};
    for (const field of Array.from(fieldIds)) {
      const value = _.result(dotaccess.get(vars, field), 'valueOf');
      if (value !== undefined) {
        // changes "foo.42.bar" -> "foo.'42'.bar" (flat.unflatten() behaves badly with numeric JSON path segments)
        const dotString = field.match(embeddedNumericRegex) ? field.replace(embeddedNumericRegex, ".'$1'.") : field;
        json[dotString] = value;
      }
    }
    json = flat.unflatten(json);

    if (json.price == null) { json.price = 0; }

    if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
      body = xmlbuilder.create({ result: json }).end({ pretty: true });
    } else {
      body = JSON.stringify(json);
    }
  }
  return body;
};

const selectMimeType = function (contentType) {
  contentType = contentType || 'application/json';
  if (contentType === '*/*') { contentType = 'application/json'; }
  return mimeparse.bestMatch(supportedMimeTypes, contentType);
};

const normalizeTrustedFormCertUrl = function (obj, isLcPing) {
  let certUrl, pingUrl;
  for (const param in obj) {
    const lowered = param.toLowerCase();
    if (lowered === 'xxtrustedformpingurl' || lowered === 'trustedform_ping_url') {
      pingUrl = obj[param];
      delete obj[param];
    } else if (lowered === 'xxtrustedformcerturl') {
      certUrl = obj[param];
      delete obj[param];
    }
  }

  if (isLcPing && pingUrl) {
    // always prefer pingUrl on ping
    obj.trustedform_cert_url = pingUrl;
  } else if (certUrl) {
    obj.trustedform_cert_url = certUrl;
  }
};

//
// Exports ----------------------------------------------------------------
//

module.exports = {
  request,
  response,
  pingable: true
};
