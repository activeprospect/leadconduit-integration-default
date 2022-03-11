const URL = require('url').URL;
const { get } = require('lodash');

const isPing = function (req) {
  if (!get(req, 'uri')) { return false; }
  let ping = false;
  try {
    const uri = new URL(req.uri, 'https://next.leadconduit.com'); // value of base param doesn't matter here
    ping = !!get(uri, 'pathname').match(/\/ping$/);
  } catch (e) {
    // swallow exceptions
  }
  return ping;
};

// given a uriString, return the query parameters in the form of an object
const parseQuery = function (uriString) {
  const uri = new URL(uriString, 'https://next.leadconduit.com'); // value of base param doesn't matter here

  // would have been nice to just return `Object.fromEntries(uri.searchParams)`,
  // but that doesn't handle multiple params (it just gives you last-one-wins)
  return [...uri.searchParams.entries()].reduce((queryParams, [key, val]) => {
    if (queryParams[key]) {
      // if the current key is already an array, add the value to it
      if (Array.isArray(queryParams[key])) {
        queryParams[key].push(val);
      } else {
        // if single value exists, convert it to an array and add value to it
        queryParams[key] = [queryParams[key], val];
      }
    } else {
      // plain assignment if no special case is present
      queryParams[key] = val;
    }
    return queryParams;
  }, {});
};

module.exports = {
  isPing,
  parseQuery
};
