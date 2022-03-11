const { assert } = require('chai');
const { isPing, parseQuery } = require('../lib/helpers');

describe('Helpers', function () {
  describe('isPing', function () {
    it('should recognize non-pings', () => {
      assert.isFalse(isPing());
      assert.isFalse(isPing(null));
      assert.isFalse(isPing({}));
      assert.isFalse(isPing('xyz'));
      assert.isFalse(isPing(45));
      assert.isFalse(isPing('https://next.leadconduit.com/flows/123/sources/456/pong'));
      assert.isFalse(isPing('https://next.leadconduit.com/flows/123/sources/456/submit?type=ping'));
    });

    it('should recognize pings', () => {
      assert.isTrue(isPing('/flows/123/sources/ping'));
      assert.isTrue(isPing('https://next.leadconduit.com/flows/123/sources/456/ping'));
      assert.isTrue(isPing('https://next.leadconduit.com/flows/123/sources/456/ping?type=whatever'));
    });
  });

  describe('parseQuery', function () {
    it('should parse the query string', () => {
      const expected = {
        foo: 'bar',
        rodeoNumber: '1',
        xxtrustedformcerturl: 'https://cert.trustedform.com/testtoken'
      };
      assert.deepEqual(parseQuery('https://url.com?foo=bar&rodeoNumber=1&xxtrustedformcerturl=https%3A%2F%2Fcert.trustedform.com%2Ftesttoken'), expected);
    });

    it('should capture multiple values from query string', () => {
      assert.deepEqual(parseQuery('https://url.com?foo=bar&foo=baz'), { foo: ['bar', 'baz'] });
    });
  });
});
