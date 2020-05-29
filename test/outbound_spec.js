const { assert } = require('chai');
const integration = require('../lib/outbound');

const requestVars = integration.request.variables().concat([
  { name: 'lead.first_name', type: 'first_name' },
  { name: 'lead.last_name', type: 'last_name' },
  { name: 'lead.email', type: 'email' },
  { name: 'lead.phone_1', type: 'phone' }
]);

const variables = require('../test/helper').variables(requestVars);


describe('Outbound Request', () => {


  it('should send accept header', () => assert.equal(integration.request(variables()).headers.Accept, 'application/json;q=0.9,text/xml;q=0.8,application/xml;q=0.7'));


  it('should encode content sent via get as querystring', () => {
    const { url } =  integration.request(variables({method: 'get'}));
    assert.equal(url, 'http://externalservice/?first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111&price=1.5');
  });


  it('should merge content sent via get over querystring', () => {
    const req = integration.request(variables({url: 'http://externalservice?first_name=Bobby&aff_id=123', method: 'get'})).url;
    assert.equal(req, 'http://externalservice/?first_name=Joe&aff_id=123&last_name=Blow&email=jblow%40test.com&phone_1=5127891111&price=1.5');
  });


  it('should handle null variable', () => {
    const { url } = integration.request(variables({lead: { first_name: null }, method: 'get'}));
    assert.equal(url, 'http://externalservice/?first_name=&last_name=Blow&email=jblow%40test.com&phone_1=5127891111&price=1.5');
  });


  it('should handle undefined variable', () => {
    const { url } = integration.request(variables({lead: { first_name: undefined }, method: 'get'}));
    assert.equal(url, 'http://externalservice/?last_name=Blow&email=jblow%40test.com&phone_1=5127891111&price=1.5');
  });


  it('should encode content sent as post', () => {
    const { body } = integration.request(variables());
    assert.equal(body, 'first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111&price=1.5');
  });


  it('should set content length of post', () => assert.equal(integration.request(variables()).headers['Content-Length'], 81));


  it('should set content type of post', () => assert.equal(integration.request(variables()).headers['Content-Type'], 'application/x-www-form-urlencoded'));


  it('should handle dot notation vars', () => {
    const { url } = integration.request({url: 'http://externalservice', method: 'get', lead: { 'deeply.nested.var': 'Hola' }});
    assert.equal(url, 'http://externalservice/?deeply.nested.var=Hola&price=0');
  });


  it('should handle deeply nested vars', () => {
    const { url } = integration.request({url: 'http://externalservice', method: 'get', lead: { deeply: { nested: { var: 'Hola' } } }});
    assert.equal(url, 'http://externalservice/?deeply.nested.var=Hola&price=0');
  });


  it('should handle new format custom fields', () => {
    const { body } = integration.request(variables({default: {custom: {favorite_color: 'pink'}}}));
    assert.equal(body, 'first_name=Joe&last_name=Blow&email=jblow%40test.com&phone_1=5127891111&favorite_color=pink&price=1.5');
  });

  it('should overwrite standard fields with custom fields of the same name', () => {
    const { body } = integration.request(variables({default: {custom: {email: 'custom@email.com'}}}));
    assert.equal(body, 'first_name=Joe&last_name=Blow&email=custom%40email.com&phone_1=5127891111&price=1.5');
  });
});

describe('Outbound Validate', () => {

  it('should require valid default_outcome', () => {
    const vars = variables({default_outcome: 'donkey'});
    assert.equal(integration.validate(vars), 'default outcome must be "success", "failure" or "error"');
  });


  it('should allow valid default_outcome', () => assert.isUndefined(integration.validate(variables({default_outcome: 'success'}))));


  it('should require url variable', () => {
    const vars = variables();
    delete vars.url;
    assert.equal(integration.validate(vars), 'URL is required');
  });


  it('should require valid url variable', () => {
    const vars = variables();
    vars.url = 'donkeykong';
    assert.equal(integration.validate(vars), 'URL must be valid');
  });


  it('should not allow head', () => assertMethodNotAllowed('head'));


  it('should not allow put', () => assertMethodNotAllowed('put'));


  it('should not allow delete', () => assertMethodNotAllowed('delete'));


  it('should not allow patch', () => assertMethodNotAllowed('patch'));
});




describe('Outbound Response', () => {

  let vars;
  let req;
  let res;

  beforeEach(() => {
    vars = variables();
    res = {
      status: 200,
      headers: {
        'Content-Type': 'application/json'
      },
      body: '{"id":42}'
    };
    req = integration.request(vars);
  });


  it('should default outcome to "error"', () => {
    const event = integration.response(vars, req, res);
    assert.equal(event.outcome, 'error');
    assert.equal(event.reason, 'Unrecognized response');
  });


  it('should default outcome to specified default', () => {
    vars = variables({default_outcome: 'success'});
    req = integration.request(vars);
    const event = integration.response(vars, req, res);
    assert.equal(event.outcome, 'success');
  });


  it('should preserve existing reason even if outcome defaults to "error"', () => {
    res.body = '{"id":42,"reason": "Big bada boom"}';
    const event = integration.response(vars, req, res);
    assert.equal(event.outcome, 'error');
    assert.equal(event.reason, 'Big bada boom');
  });



  it('should parse XML response', () => {
    res.headers['Content-Type'] = 'text/xml';
    res.body = xmlBody();
    const event = integration.response(vars, req, res);
    const expected = {
      outcome: 'success',
      reason: '',
      lead: {
        id: '1234',
        last_name: 'Blow',
        email: 'jblow@test.com',
        phone_1: '5127891111'
      },
      price: '1.5'
    };
    assert.deepEqual(event, expected);
  });


  it('should handle poorly formed XML response', () => {
    // uses sample invalid XML from customer
    res.headers['Content-Type'] = 'text/xml';
    res.body = '<status>Error</status><reason>Please send in the mg_site_id and mg_cid as part of your request. Request Parameter = mg_site_id</reason>';
    const event = integration.response(vars, req, res);
    assert.deepEqual(event, {outcome: 'error', reason: 'Unrecognized response'});
  });


  it('should parse JSON response', () => {
    const expected = {
      outcome: 'success',
      reason: '',
      lead: {
        id: '1234',
        last_name: 'Blow',
        email: 'jblow@test.com',
        phone_1: '5127891111'
      },
      price: 1.5
    };
    res.body = JSON.stringify(expected);
    const event = integration.response(vars, req, res);
    assert.deepEqual(event, expected);
  });


  it('should use handler "message" as error reason', () => {
    const expected = {
      outcome: 'error',
      reason: 'Flow is disabled'
    };

    res = {
      status: 403,
      headers: {
        'Content-Type': 'application/json'
      },
      body: '{ "message": "Flow is disabled" }'
    };

    const event = integration.response(vars, req, res);
    assert.deepEqual(event, expected);
  });
});


var assertMethodNotAllowed = function(method) {
  const vars = variables();
  vars.method = method;
  try {
    assert.equal(integration.validate(vars), `Unsupported HTTP method ${method.toUpperCase()}. Use GET or POST.`);
  } catch (error) {}
};


var xmlBody = () =>
  `\
<result>
  <outcome>success</outcome>
  <reason/>
  <lead>
    <id>1234</id>
    <last_name>Blow</last_name>
    <email>jblow@test.com</email>
    <phone_1>5127891111</phone_1>
  </lead>
  <price>1.5</price>
</result>\
`
;

