const { assert } = require('chai');
const { isPing } = require('../lib/helpers');

describe('IsPing', function () {
  it('should recognize non-pings', () => {
    assert.isFalse(isPing());
    assert.isFalse(isPing(null));
    assert.isFalse(isPing({}));
    assert.isFalse(isPing({ uri: 'xyz' }));
    assert.isFalse(isPing({ uri: 45 }));
    assert.isFalse(isPing({ uri: 'https://next.leadconduit.com/flows/123/sources/456/pong' }));
    assert.isFalse(isPing({ uri: 'https://next.leadconduit.com/flows/123/sources/456/submit?type=ping' }));
  });

  it('should recognize pings', () => {
    assert.isTrue(isPing({ uri: '/flows/123/sources/ping' }));
    assert.isTrue(isPing({ uri: 'https://next.leadconduit.com/flows/123/sources/456/ping' }));
    assert.isTrue(isPing({ uri: 'https://next.leadconduit.com/flows/123/sources/456/ping?type=whatever' }));
  });
});
