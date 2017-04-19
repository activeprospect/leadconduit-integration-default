inbound = require('./lib/inbound');
module.exports = {
  name: 'LeadConduit',
  inbound: inbound,
  'inbound.inbound': inbound,
  'inbound.verbose': require('./lib/verbose'),
  outbound: require('./lib/outbound')
};
