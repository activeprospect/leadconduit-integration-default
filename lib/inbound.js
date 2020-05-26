const _ = require('lodash');
const dotaccess = require('dotaccess');
const mimecontent = require('mime-content');
const mimeparse = require('mimeparse');
const querystring = require('querystring');
const xmlbuilder = require('xmlbuilder');
const flat = require('flat');
const url = require('url');
const { HttpError } = require('leadconduit-integration');


const supportedMimeTypes = [
  'application/x-www-form-urlencoded',
  'application/json',
  'application/xml',
  'text/xml'
];

const supportedMimeTypeLookup = supportedMimeTypes.reduce((function(lookup, mimeType) {
  lookup[mimeType] = true;
  return lookup;
}), {});


//
// Request Function -------------------------------------------------------
//

const request = function(req) {

  // ensure supported method
  let e;
  const method = req.method != null ? req.method.toLowerCase() : undefined;
  if ((method !== 'get') && (method !== 'post')) {
    throw new HttpError(405, { 'Content-Type': 'text/plain', Allow: 'GET, POST' }, `The ${method.toUpperCase()} method is not allowed`);
  }

  // ensure acceptable content type, preferring JSON
  let mimeType = selectMimeType(req.headers['Accept']);
  if (!mimeType) {
    throw new HttpError(406, { 'Content-Type': 'text/plain' }, "Not capable of generating content according to the Accept header");
  }

  // parse the query string
  const uri = url.parse(req.uri, true);
  const query = flat.unflatten(uri.query);

  // find the redir url
  let redirUrl = query.redir_url;

  if (redirUrl != null) {
    if (_.isArray(redirUrl)) { redirUrl = redirUrl[0]; }
    try {
      redirUrl = url.parse(redirUrl);
      if (!redirUrl.slashes || ((redirUrl.protocol !== 'http:') && (redirUrl.protocol !== 'https:'))) {
        throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url');
      }
    } catch (error) {
      e = error;
      throw new HttpError(400, { 'Content-Type': 'text/plain' }, 'Invalid redir_url');
    }
  }

  normalizeTrustedFormCertUrl(query);

  if (method === 'get') {
    return query;

  } else if (method === 'post') {

    if ((req.headers['Content-Length'] != null) || (req.headers['Transfer-Encoding'] === 'chunked')) {
      // assume a request body

      // ensure a content type header
      const contentType = req.headers['Content-Type'];
      if (!contentType) {
        throw new HttpError(415, {'Content-Type': 'text/plain'}, 'Content-Type header is required');
      }

      // ensure valid mime type
      mimeType = selectMimeType(req.headers['Content-Type']);
      if (supportedMimeTypeLookup[mimeType] == null) {
        throw new HttpError(406, {'Content-Type': 'text/plain'}, `MIME type in Content-Type header is not supported. Use only ${supportedMimeTypes.join(', ')}.`);
      }

      // parse request body according the the mime type
      const body = req.body != null ? req.body.trim() : undefined;
      if (!body) { return query; }
      let parsed = mimecontent(body, mimeType);

      // if form URL encoding, convert dot notation keys
      if (mimeType === 'application/x-www-form-urlencoded') {
        try {
          parsed = flat.unflatten(parsed);
        } catch (error1) {
          e = error1;
          const formEncodedError = e.toString();
          throw new HttpError(400, {'Content-Type': 'text/plain'}, `Unable to parse body -- ${formEncodedError}.`);
        }
      }

      // if XML, turn doc into an object
      if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
        try {
          parsed = parsed.toObject({explicitArray: false, explicitRoot: false, mergeAttrs: true});
        } catch (error2) {
          e = error2;
          const xmlError = e.toString().replace(/\r?\n/g, " ");
          throw new HttpError(400, {'Content-Type': 'text/plain'}, `Body does not contain XML or XML is unparseable -- ${xmlError}.`);
        }
      }


      // merge query string data into data parsed from request body
      _.merge(parsed, query);

      normalizeTrustedFormCertUrl(parsed);

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

request.examples = function(flowId, sourceId, params) {
  const baseUri = `/flows/${flowId}/sources/${sourceId}/submit`;
  let getUri = baseUri;
  if (__guard__(Object.keys(params), x => x.length)) { getUri = `${getUri}?${querystring.encode(params)}`; }

  let postUri = baseUri;
  if (params.redir_url) {
    postUri = `${postUri}?redir_url=${encodeURIComponent(params.redir_url)}`;
    delete params.redir_url;
  }

  const xml = xmlbuilder.create('lead');
  for (let name in params) {
    const value = params[name];
    xml.element(name, value);
  }
  const xmlBody = xml.end({pretty: true});

  return [
    {
      method: 'POST',
      uri: postUri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: querystring.encode(params)
    },
    {
      method: 'GET',
      uri: getUri,
      headers: {
        'Accept': 'application/json'
      }
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(params, null, 2)
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        'Accept': 'text/xml',
        'Content-Type': 'text/xml'
      },
      body: xmlBody
    },
    {
      method: 'POST',
      uri: postUri,
      headers: {
        'Accept': 'text/xml',
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

const response = function(req, vars, fieldIds) {
  if (fieldIds == null) { fieldIds = ['outcome', 'reason', 'lead.id', 'price']; }
  const mimeType = selectMimeType(req.headers['Accept']);

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

  // parse the query string
  const uri = url.parse(req.uri);
  const query = flat.unflatten(querystring.parse(uri.query));

  // find the redir url
  const redirUrl = _.isArray(query.redir_url) ? query.redir_url[0] : query.redir_url;

  const status = (redirUrl != null) ? 303 : statusCode;

  const headers = {
    'Content-Type': mimeType,
    'Content-Length': body.length
  };

  if (redirUrl != null) { headers['Location'] = redirUrl; }

  return {
    status,
    headers,
    body
  };
};


response.variables = function(forPing) {
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

var buildBody = function(mimeType, fieldIds, vars) {
  let body = null;
  if (mimeType === 'text/plain') {
    body = '';
    if (fieldIds.include('lead.id')) { body += `lead_id:${vars.lead.id}\n`; }
    if (fieldIds.include('outcome')) { body += `outcome:${vars.outcome}\n`; }
    if (fieldIds.include('reason')) { body += `reason:${vars.reason}\n`; }
    if (fieldIds.include('price')) { body += `price:${vars.price || 0}\n`; }
  } else {
    let json = {};
    for (let field of Array.from(fieldIds)) {
      const value = __guard__(dotaccess.get(vars, field), x => x.valueOf());
      if (value !== undefined) { json[field] = value; }
    }
    json = flat.unflatten(json);

    if (json.price == null) { json.price = 0; }

    if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
      body = xmlbuilder.create({result: json}).end({pretty: true});
    } else {
      body = JSON.stringify(json);
    }
  }
  return body;
};


var isPing = function(req) {
  if (!(req != null ? req.uri : undefined)) { return false; }
  const uri = url.parse(req.uri);
  return !!__guard__(uri != null ? uri.pathname : undefined, x => x.match(/\/ping$/));
};


var selectMimeType = function(contentType) {
  contentType = contentType || 'application/json';
  if (contentType === '*/*') { contentType = 'application/json'; }
  return mimeparse.bestMatch(supportedMimeTypes, contentType);
};


var normalizeTrustedFormCertUrl = obj =>
  (() => {
    const result = [];
    for (let param in obj) {
      const value = obj[param];
      if ((param != null ? param.toLowerCase() : undefined) === 'xxtrustedformcerturl') {
        obj.trustedform_cert_url = value;
        result.push(delete obj[param]);
      } else {
        result.push(undefined);
      }
    }
    return result;
  })()
;




//
// Exports ----------------------------------------------------------------
//

module.exports = {
  name: 'Standard',
  request,
  response,
  pingable: true
};

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}