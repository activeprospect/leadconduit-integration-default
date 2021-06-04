const URL = require('url').URL;
const { get } = require('lodash');

const isPing = function (req) {
  if (!(req != null ? req.uri : undefined)) { return false; }
  let ping = false;
  try {
    const uri = new URL(req.uri, 'https://next.leadconduit.com'); // value of base param doesn't matter
    ping = !!get(uri, 'pathname').match(/\/ping$/);
  } catch (e) {
    // swallow exceptions
  }
  return ping;
};

module.exports = {
  isPing
};
