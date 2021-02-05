ruleset my.twilio2 {
  meta {
    name "my.twilio"
    description << A test module for twilio >>
    author "Forrest Olson"
    configure using 
      apiToken = meta:rulesetConfig{"apiToken"}
      apiSid = meta:rulesetConfig{"apiSid"}
      apiPhone = meta:rulesetConfig{"apiPhone"}
      // apiToken = ""
      // apiSid = ""
      // apiPhone = ""
    provides getMessages, sendMessage
    shares getCreds, getMessages, lastResponse
  }

  global {
    base_url = "https://api.twilio.com"

    // Write a user-defined action to send an SMS
    getCreds = function () {
      return {"sid": apiSid, "token": apiToken}
    }
    sendMessage = defaction(to, msg) {
      queryString = {} //"api_token":apiToken actually a map...
      body = {"Body":msg, "To":to, "From":apiPhone}
      auth = {"user": apiSid, "password": apiToken}.klog("authorization")
      // result = http:post(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages.json>>, qs=queryString, json=body, auth=apiToken)
      // result
      // might drop the .json below
      http:post(<<https://#{apiSid}:#{apiToken}@api.twilio.com/2010-04-01/Accounts/#{apiSid}/Messages.json>>, form=body) setting(response)
      // http:post(<<#{base_url}/2010-04-01/Accounts/#{apiSid}/Messages.json>>, form=body, auth=auth) setting (response)
      return response
      // setting(response)

    }

    // Write a function to return a page of messages sent
    getMessages = function(pages = none, sendFilter = none, receiveFilter = none) {
      queryString = sendFilter => 
                      (receiveFilter => {"to":receiveFilter, "from":sendFilter} | {"from":sendFilter}) | 
                      (receiveFilter => {"to":receiveFilter} | {})
                      // "pageSize"
      auth = {"username":apiSid, "password":apiToken}
      // queryString = queryString.put("api_token", apiToken).put("api_sid", apiSid)
      response = http:get(<<https://#{apiSid}:#{apiToken}@api.twilio.com/2010-04-01/Accounts/#{apiSid}/Messages.json>>, qs=queryString, pageSize=100)
      response{"content"}.decode(){"messages"}
    }
    // messages = getMessages
    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }

  }

  rule test_send {
    select when test send

    pre {
      mess = event:attrs{"message"}
    }

    sendMessage("14357549364", mess)

  }

  rule r2 {
    select when http post

    pre {
      response = event:attrs{"response"} || none
    }

    send_directive("Page says...", {"respo":event:attrs{"response"}});

    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    }
  }

  // rule test_messages {
  //   select when test messages

  //   pre {
  //     pages = event:attrs{"pages"} => event:attrs{"pages"} | none
  //     fromFilter = event:attrs{"from"} => event:attrs{"from"} | none
  //     toFilter = event:attrs{"to"} => event:attrs{"to"} | none
  //   }

  //   getMessages(pages, fromFilter, toFilter)

  // }
}