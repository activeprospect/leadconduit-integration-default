const _ = require('lodash');
const mimecontent = require('mime-content');
const mimeparse = require('mimeparse');
const querystring = require('querystring');
const flat = require('flat');
const URL = require('url').URL;

//
// Request Function --------------------------------------------------------
//

const request = function (vars) {
  let key, value;
  const method = (vars.method != null ? vars.method.toUpperCase() : undefined) || 'POST';

  // the preferred resource content-types
  const acceptHeader = 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7';

  // build lead data
  let dataToSend = {};
  const leadData = flat.flatten(vars.lead);
  for (key in leadData) {
    // fields with undefined as the value are not included
    value = leadData[key];
    if (typeof value === 'undefined') { continue; }
    // use valueOf to ensure the normal version is sent for all richly typed values
    dataToSend[key] = _.result(value, 'valueOf');
  }

  if (vars.default != null ? vars.default.custom : undefined) {
    const object1 = flat.flatten(vars.default.custom, { safe: true });
    for (key in object1) {
      value = object1[key];
      if (value) dataToSend[key] = _.result(value, 'valueOf');
    }
  }

  dataToSend.price = (vars.price) ? vars.price.valueOf() : 0;

  if (method === 'GET') {
    const url = new URL(vars.url);
    // merge lead values over existing searchParams (querystring) as needed
    for (key in dataToSend) {
      value = dataToSend[key];
      url.searchParams.set(key, typeof value === 'undefined' ? '' : value);
    }

    return {
      url: url.toString(), // includes full query string from searchParams
      method,
      headers: {
        Accept: acceptHeader
      }
    };
  } else if (method === 'POST') {
    // URL encoded post body
    dataToSend = querystring.encode(dataToSend);

    return {
      url: vars.url,
      method,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': dataToSend.length,
        Accept: acceptHeader
      },
      body: dataToSend
    };
  }
};

//
// Response Function --------------------------------------------------------
//

const response = function (vars, req, res) {
  const { body } = res;

  const contentType = res.headers['Content-Type'];

  // ensure content type header was returned by server
  if (contentType == null) {
    return { outcome: 'error', reason: 'No Content-Type specified in server response' };
  }

  // ensure valid mime type
  const mimeType = bestMimeType(contentType);
  if (!mimeType) {
    return { outcome: 'error', reason: 'Unsupported Content-Type specified in server response' };
  }

  let event = mimecontent(body, mimeType);

  if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
    event = event.toObject({ explicitArray: false, explicitRoot: false, mergeAttrs: true });
  }

  if ((event.outcome == null)) {
    event = {
      outcome: vars.default_outcome || 'error',
      reason: event.reason || event.message || 'Unrecognized response'
    };
  }

  return event;
};

//
// Variables --------------------------------------------------------------
//

request.variables = () =>
  [
    { name: 'url', description: 'Server URL', type: 'string', required: true },
    { name: 'method', description: 'HTTP method (GET or POST)', type: 'string', required: true },
    { name: 'default_outcome', description: 'Outcome to return if recipient returns none (success, failure, error). If not specified, "error" will be used.', type: 'string' },
    { name: 'lead.*', type: 'wildcard', required: true },
    { name: 'default.custom.*', type: 'wildcard', required: false },
    { name: 'price', type: 'number', description: 'The price of the lead' }
  ]
;

response.variables = () =>
  [
    { name: 'outcome', type: 'string', description: 'The outcome of the transaction (default is success)' },
    { name: 'reason', type: 'string', description: 'If the outcome was a failure, this is the reason' },
    { name: 'price', type: 'number', description: 'The price of the lead' }
  ]
;

//
// Helpers ----------------------------------------------------------------
//

const supportedMimeTypes = [
  'application/json',
  'application/xml',
  'text/xml'
];

const supportedMimeTypeLookup = supportedMimeTypes.reduce(function (lookup, mimeType) {
  lookup[mimeType] = true;
  return lookup;
}, {});

const bestMimeType = function (contentType) {
  let mimeType = mimeparse.bestMatch(supportedMimeTypes, contentType);
  if (supportedMimeTypeLookup[mimeType] == null) {
    mimeType = null;
  }
  return mimeType;
};

const isValidUrl = url =>
  (url.protocol != null) &&
  url.protocol.match(/^http[s]?:/) &&
  (url.hostname != null)
;

const validate = function (vars) {
  if ((vars.default_outcome != null) && !vars.default_outcome.match(/success|failure|error/)) {
    return 'default outcome must be "success", "failure" or "error"';
  }

  // validate URL
  if (vars.url == null) {
    return 'URL is required';
  }

  try {
    const url = new URL(vars.url);
    if (!isValidUrl(url)) {
      return 'URL must be valid';
    }
  } catch (e) {
    return 'URL must be valid';
  }

  // validate method
  const method = (vars.method != null ? vars.method.toUpperCase() : undefined) || 'POST';
  if ((method !== 'GET') && (method !== 'POST')) {
    return 'Unsupported HTTP method - use GET or POST';
  }
};

//
// Exports ----------------------------------------------------------------
//

module.exports = {
  request,
  response,
  validate
};
