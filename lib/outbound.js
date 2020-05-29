const _ = require('lodash');
const mimecontent = require('mime-content');
const mimeparse = require('mimeparse');
const querystring = require('querystring');
const xmlbuilder = require('xmlbuilder');
const flat = require('flat');
const u = require('url');



//
// Request Function --------------------------------------------------------
//

const request = function(vars) {

  let key, value;
  const url = u.parse(vars.url);
  const method = (vars.method != null ? vars.method.toUpperCase() : undefined) || 'POST';

  // the preferred resource content-types
  const acceptHeader = 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7';

  // build lead data
  let content = {};
  const object = flat.flatten(vars.lead);
  for (key in object) {
    // fields with undefined as the value are not included
    value = object[key];
    if (typeof value === 'undefined') { continue; }
    // use valueOf to ensure the normal version is sent for all richly typed values
    content[key] = _.result(value, 'valueOf');
  }

  if (vars.default != null ? vars.default.custom : undefined) {
    const object1 = flat.flatten(vars.default.custom, {safe: true});
    for (key in object1) {
      value = object1[key];
      if(value) content[key] = _.result(value, 'valueOf');
    }
  }

  content.price = (vars.price) ? vars.price.valueOf() : 0;

  if (method === 'GET') {

    // build query string, merging 'over' existing querystring
    const query = querystring.parse(url.query || '');
    for (key in content) {
      value = content[key];
      query[key] = value;
    }

    url.query = query;
    delete url.search;

    return {
      url: u.format(url),
      method,
      headers: {
        'Accept': acceptHeader
      }
    };

  } else if (method === 'POST') {

    // URL encoded post body
    content = querystring.encode(content);

    return {
      url: vars.url,
      method,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': content.length,
        'Accept': acceptHeader
      },
      body: content
    };
  }
};



//
// Response Function --------------------------------------------------------
//

const response = function(vars, req, res) {
  const { body } = res;

  const contentType = res.headers['Content-Type'];

  // ensure content type header was returned by server
  if (contentType == null) {
    return {outcome: 'error', reason: 'No Content-Type specified in server response'};
  }

  // ensure valid mime type
  const mimeType = bestMimeType(contentType);
  if (!mimeType) {
    return {outcome: 'error', reason: 'Unsupported Content-Type specified in server response'};
  }

  let event = mimecontent(body, mimeType);

  if ((mimeType === 'application/xml') || (mimeType === 'text/xml')) {
    event = event.toObject({explicitArray: false, explicitRoot: false, mergeAttrs: true});
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
  'text/xml',
];


const supportedMimeTypeLookup = supportedMimeTypes.reduce((function(lookup, mimeType) {
  lookup[mimeType] = true;
  return lookup;
}), {});


var bestMimeType = function(contentType) {
  let mimeType = mimeparse.bestMatch(supportedMimeTypes, contentType);
  if (supportedMimeTypeLookup[mimeType] == null) {
    mimeType = null;
  }
  return mimeType;
};


const isValidUrl = url =>
  (url.protocol != null) &&
  url.protocol.match(/^http[s]?:/) &&
  url.slashes &&
  (url.hostname != null)
;


const validate = function(vars) {
  if ((vars.default_outcome != null) && !vars.default_outcome.match(/success|failure|error/)) {
    return 'default outcome must be "success", "failure" or "error"';
  }

  // validate URL
  if (vars.url == null) {
    return 'URL is required';
  }

  const url = u.parse(vars.url);

  if (!isValidUrl(url)) {
    return 'URL must be valid';
  }

  // validate method
  const method = (vars.method != null ? vars.method.toUpperCase() : undefined) || 'POST';
  if ((method !== 'GET') && (method !== 'POST')) {
    return "Unsupported HTTP method - use GET or POST";
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

