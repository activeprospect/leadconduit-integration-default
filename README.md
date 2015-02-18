# LeadConduit Default Integration

This module is for use on the [LeadConduit](http://activeprospect.com/products/leadconduit/) platform. Please see the [license agreement](http://creativecommons.org/licenses/by-nc-nd/4.0/)


[![Build Status](https://travis-ci.org/activeprospect/leadconduit-integration-default.svg?branch=master)](https://travis-ci.org/activeprospect/leadconduit-integration-default)

## Outbound 

Responses to the "Generic POST" outbound must be XML or JSON, as in the examples below. 

Data in the response will be automatically appended to the lead. Other than including data for the special keys `outcome` and `reason`, there is not currently a way to set those values.

### XML

The response `Content-Type` must be either `application/xml` or `text/xml`.

```xml
<result>
  <outcome>success</outcome>
  <reason/>
  <lead>
    <id>1234</id>
    <last_name>Smith</last_name>
    <email>jsmith@test.com</email>
    <phone_1>5125551234</phone_1>
  </lead>
</result>
```

All data under the top level (`<result>`, in this example) will be appended to the lead. For example, if the recipient name is "My CRM", the lead will include appended data for "My CRM Lead Last Name" (aka `my_crm.lead.last_name`) of "Smith".

### JSON

The response `Content-Type` must be `application/json`.

```json
{
  "outcome": "success",
  "reason": "",
  "lead": {
    "id": "1234",
    "last_name": "Smith",
    "email": "jsmith@test.com",
    "phone_1": "5125551234",
  }
}
```

As above, all data will be appended to the lead. For example, if the recipient name is "My CRM", the lead will include appended data for "My CRM Lead Last Name" (aka `my_crm.lead.last_name`) of "Smith".
