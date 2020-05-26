const dotaccess = require('dotaccess');
const flat = require('flat');
const { types } = require('leadconduit-integration').test;


module.exports = {
  variables(requestVariables) {
    const parse = types.parser(requestVariables);

    return function(override) {

      if (override == null) { override = {}; }
      override = flat.flatten(override, {safe: true});

      const vars = {
        url: 'http://externalservice',
        method: 'post',
        lead: {
          first_name: 'Joe',
          last_name: 'Blow',
          email: 'JBLOW@TEST.COM',
          phone_1: '512-789-1111'
        },
        price: 1.5
      };

      for (let key in override) {
        const value = override[key];
        dotaccess.set(vars, key, value, true);
      }

      return parse(vars);
    };
  }
};
